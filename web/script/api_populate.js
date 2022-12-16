
function api_clips_str(api_root, page=undefined){
    console.log(`dfadada => ${api_root}/clips${(Boolean(page))?`?pageNum=${page}`:''}`)
    return `${api_root}/clips${(Boolean(page))?`?pageNum=${page}`:''}`
}

function _add_btn($elmt, page, totalPages){
    $elmt.append("<br/>")
    if(page>1){
        $("<a href=\"?page="+(page-1)+"\" class=\"button\"><-</a>").appendTo($elmt)
    }
    if(totalPages>2){
        $("<input type=\"number\" class=\"page-choice\" value=\""+page+"\"/><span class=\"total-page-count\">/"+totalPages+"</span>").appendTo($elmt)
    }
    if(page<totalPages){
        $("<a href=\"?page="+(page+1)+"\" class=\"button\">-></a>").appendTo($elmt)
    }
}

function __lookForClipInPage(clip_id, page, api_root){
    return fetch( api_clips_str(api_root, page) )
    .then(response => response.json())
    .then(clips_obj => {
        last_clip= clips_obj.clips.at(-1)
        first_clip= clips_obj.clips.at(0)

        if(last_clip._id>clip_id){
            return -1
        }
        else if(first_clip._id<clip_id){
            return 1
        }
        else if(clips_obj.clips.find(c => {return (c._id===clip_id)})){
            return 0
        }
        else{
            throw "clip doesn't exist or is badly stored - should be in page "+page
        }
    })
}

async function _findPageForClipFromId(clipID, clips, api_root){
    console.log("look!")
    var cpp= clips.perPage
    var ctp= clips.totalPages
    var acc= clips.availableClipsCount

    var rev_clipID= Math.max(0,(acc-clipID+1))

    var th_page= Math.ceil(Math.max(0, Math.min((rev_clipID/cpp)-(1/(cpp+1)), ctp)))
    
    var search_dir= 0
    var first_dir= 0
    do{
        console.log(`${search_dir}; ${first_dir}`)
        search_dir= await __lookForClipInPage(clipID, th_page, api_root)
        console.log("====> got sd= "+search_dir+" from th_page= "+th_page)
        if(search_dir===0){
            return th_page
        }else{
            if(first_dir===0) first_dir= search_dir
            else if(search_dir!==first_dir){
                throw "clip doesn't exist or is badly stored - look up failed"
            }

            th_page-= search_dir
        }
    } while(0<th_page && th_page<=ctp)

    return undefined
}

function populate(api_root, $parent, infos){
    $.ajaxSetup({ cache: false });

    var pageNum= Boolean(infos.pageNum)?infos.pageNum:1
    var clip_id= infos.clip_id
    var clip_id= (clip_id<1)?1:clip_id

    return fetch( api_clips_str(api_root, pageNum) )
    // .then(response => response.json())
    .then(async response => {
        if(response.status===204){
            return await fetch( api_clips_str(api_root) ).then(_response => _response.json())
        }
        else{
            return response.json()
        }
    })
    .then(async response => {
        var clips_obj= response

        var page= pageNum
        if(clip_id && !Boolean(clips_obj.clips.find(c => c._id===clip_id))){
            page= await _findPageForClipFromId(clip_id, clips_obj, api_root)
                .then(p => {
                    if(Boolean(p)) return p
                    else return pageNum
                })
                .catch(err => {
                    return pageNum
                })

            console.log("NEW PAGE!!!! "+page)

            if(page!==pageNum){
                clips_obj= await fetch( api_clips_str(api_root, page) )
                    .then(response => response.json())
                    .catch(err => clips_obj)
            }
        }

        $.each(clips_obj.clips, (id, element) => {
            console.log(`element: ${JSON.stringify(element)}`)
            if(element && element.type && element.url){
                var a=$(
                    "<a class=\"gallery-element\" id=\""+element._id+"\" src=\""+element.url+"\" src-type=\""+element.type+"\">"+
                        "<div>"+
                            ((Boolean(element.thumbnail))? ("<img src="+element.thumbnail+" />") : "")+
                            "<img class=\"placeholder\" src=\"\./img/gallery/"+((element.type==='gif')?'gif':'vid')+"-icon.png\" />"+
                        "</div></a>"
                ).appendTo($parent)
                if(element.description && element.description.length>0){
                    $("<span hidden class=\"gallery-element-description\">"+element.description+"</span>").appendTo($(a))
                }
                if(element.timestamp && element.timestamp.length>0){
                    $("<time hidden class=\"gallery-element-timestamp\">"+element.timestamp+"</time>").appendTo($(a))
                }
            }
        })

        if (clips_obj.clips.length>0){
            _add_btn($parent, clips_obj.page, clips_obj.totalPages)
        }

        return {success: true, target_clip: infos.clip_id};
    })
}