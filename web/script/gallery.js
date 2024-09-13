
var cur_selected= null

function _extractVideoId(src_type, url){
    switch (src_type){
        case "youtube":
            return url.match(/((youtube\.com.*(\?v=|\/embed\/|shorts\/))|(youtu\.be\/))(.{11})/).pop()
        case "streamable.com":
            return url.match(/streamable\.com\/(.*)/).pop()
        default:
            return null
    }
}


function process_source(element){
    var source= $(element).attr('src')
    var source_type= $(element).attr('src-type')
    var div= $(element).children('div')
    if (source) {
        if (source_type==="gif"){
            var c= $("<canvas class=\"gif\"></canvas>").appendTo(div)[0]
            // $("<img src=\"./img/gallery/gif-icon.png\">").appendTo(c)
            isC = !!(c.getContext && c.getContext('2d'))
            var img= new Image()
            img.src= source
            img.onload= function(){
                var hratio= c.height/img.height
                c.width= img.width*hratio
                c.getContext('2d').drawImage(img, 0,0, c.width, c.height)
                delete img
            }
        }
        else if(source_type==="video"){
            var c= $("<canvas class=\"vid\"></canvas>").appendTo(div)[0]
            isC = !!(c.getContext && c.getContext('2d'))
            var v= document.createElement("video")
            v.setAttribute("src",source)
            v.onloadeddata= function(){
                var hratio= c.height/v.videoHeight
                c.width= v.videoWidth*hratio
                c.getContext('2d').drawImage(v, 0,0,c.width,c.height)
                delete v
            }
        }
        else if (source_type==='youtube'){
            var v_id=_extractVideoId(source_type,source)
            if (v_id){
                $(div).append("<img src=\"https://img.youtube.com/vi/"+v_id+"/0.jpg\"/>")
            }
        }
        else if (source_type==="streamable.com"){
            var v_id=_extractVideoId(source_type,source)            
            if (v_id){
                $(div).append("<img src=\"https://cdn-cf-east.streamable.com/image/"+v_id+".jpg\"/>")
            }
        }
        else{
            $(div).append("<img src=\""+source+"\"/>")
        }
        $(
            "<img class=\"placeholder\" src=\"\./img/gallery/"
            +((source_type==='gif')?'gif':'vid')+"-icon.png\"/>"
        ).appendTo(div)
    }
}

var displayer= null

function clear_displayer(){
    if(displayer){
        displayer.children("div.display-content").empty()
    }
}

function update_displayer(){
    if (displayer && cur_selected){
        var source= cur_selected.attr('src')
        var source_type= cur_selected.attr('src-type')
        var source_id= cur_selected.attr('id')

        var clip_thumb= cur_selected.children("div").children("img.clip_thumbnail").attr('src')

        switch (source_type){
            case "gif":
                displayer.children("div.display-content").append("<img src=\""+source+"\" fetchpriority=\"high\"/>")
            break;
            case "video":
                displayer.children("div.display-content").append(
                    "<video controls preload=\"auto\" fetchpriority=\"high\" poster=\""+clip_thumb+"\" src=\""+source+"\">"+
                    "Your browser does not support the video tag.</video>"
                )
            break;
            case "youtube":
                displayer.children("div.display-content").append(
                    "<iframe src=\"https://www.youtube.com/embed/"+_extractVideoId(source_type, source)+"\" "+
                        "title=\"YouTube video player\" frameborder=\"0\" scrolling=\"no\" "+
                        "allow=\"accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture\" allowfullscreen>"+
                    "</iframe>"
                );
            break;
            case "streamable.com":
                displayer.children("div.display-content").append(
                    "<iframe class=\"streamable-embed\" "+
                        "src=\"https://streamable.com/o/"+_extractVideoId(source_type, source)+"\" "+
                        "frameborder=\"0\" scrolling=\"no\" "+
                        "allowfullscreen>"+
                    "</iframe>"
                );
            break;
            default:
                console.log("nope")
        }


        var contentInfo= $("<div class=\"content-info\"></div>").appendTo(displayer.children("div.display-content"))
        if(source_id && source_id.length>0){
            contentInfo.append("Clip ID: "+source_id+"<br/>")
        }

        var ts= cur_selected.children("time.gallery-element-timestamp")
        if (ts && ts.text()){
            contentInfo.append(ts.text()+"<br/>")
        }

        if(source_id && source_id.length>0){
            var $t;
            ($t= $(  "<div><span class=\"notif\">Copied! </span>"
                +"<span class=\"share-link\">Share link: <a class=\"share-link\">[ 📋 ]</a></span></br></div>"
            )).appendTo(
                contentInfo
            ).click( () => {
                navigator.clipboard.writeText(
                    `https://strashbot.fr/gallery.html?clip=${source_id}`
                );

                $target= $t.children('span.notif:first-child')
                $target.removeClass('copied-text')
                $newone= $target.clone(true)

                $target.replaceWith($newone)
                $newone.addClass('copied-text')


                return false;
            })
        }

        if (source){
            contentInfo.append("Direct link: <a href=\""+source+"\" target=\"_blank\">[ 🔗 ]</a><br/>")
        }



        var desc= cur_selected.children("span.gallery-element-description")
        if (desc && desc.text()){
            // displayer.children("div.display-content").append(desc.text())
            $("<span class=\"content-description\">"+desc.text()+"</span>").appendTo(displayer.children("div.display-content"))
        }
    }
}

function displayer_left(){
    clear_displayer();
    var t= null;
    if (cur_selected){
        t= cur_selected.prev("div.gallery a.gallery-element")
    }
    
    cur_selected= (t && t.length!==0)? t : ($("div.gallery a.gallery-element").last());

    update_displayer()
}

function displayer_right(){
    clear_displayer();
    var t= null;
    if (cur_selected){
        t= cur_selected.next("div.gallery a.gallery-element")
    }
    
    cur_selected= (t && t.length!==0)? t : ($("div.gallery a.gallery-element").first());

    update_displayer()
}

function displayer_close(){
    cur_selected= null
    displayer.hide()
    clear_displayer()
}

function gallery(clip_id){

    displayer= $("div.display")

    displayer.hide()

    $("div.gallery a.gallery-element").each(function(index, element){
        // process_source(element)

        let _show_clip= (elmt) => {
            displayer.show()

            cur_selected= $(elmt)

            update_displayer()
        }

        $(element).click(function(){
            _show_clip(this)
        })
            

        if($(element).attr('id')===`${clip_id}`){
            _show_clip(element)
        }
    })
    displayer.click(function(){
        if (displayer.is(":visible")){
            displayer_close()
        }
    })

    $("div#l-arrow").click(function(event){
        event.stopPropagation();

        displayer_left();
    })

    $("div#r-arrow").click(function(event){
        event.stopPropagation();

        displayer_right();
    })

    $("div#close").click(function(event){
        event.stopPropagation();

        if (displayer.is(":visible")){
            displayer_close()
        }
    })
    
    $("input.page-choice").keyup(function(e){
        if(e.keyCode == 13)
        {
            var val= parseInt($( this ).val())
            if(!isNaN(val)){
                window.location.href = "?page="+val;
            }
            else{
                $( this ).val('')
            }
        }
    })



    $( this ).keyup(function( event ) {
        if(displayer && displayer.is(":visible")){
            switch( event.keyCode ) {
                case 37:
                    displayer_left();

                    break;
                case 39:
                    displayer_right();

                    break;
                case 27:
                    displayer_close();

                    break;
            }
        }
    })
}
