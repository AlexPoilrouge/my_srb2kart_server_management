


function populate(json_dir_url, $parent, done, pageNum=1){
    $.ajaxSetup({ cache: false });

    var json_info_url= json_dir_url+"/gallery.json"

    var _add_btn= function($p, page, numpages){
        $p.append("<br/>")
        if(page>1){
            $("<a href=\"?page="+(page-1)+"\" class=\"button\"><-</a>").appendTo($p)
        }
        if(numpages>2){
            $("<input type=\"number\" class=\"page-choice\" value=\""+page+"\"/><span class=\"total-page-count\">/"+numpages+"</span>").appendTo($p)
        }
        if(page<numpages){
            $("<a href=\"?page="+(page+1)+"\" class=\"button\">-></a>").appendTo($p)
        }
    }

    $.getJSON(json_info_url, function(data){
        var num_entries= data.number
        var picPerPage= data.entries_per_page
        var num_pages= Math.floor(num_entries/picPerPage)+((num_entries%picPerPage)?1:0)
        var p_n= (pageNum<1)?1:((pageNum>num_pages)?num_pages:pageNum)

        var json_page_url= json_dir_url+"/gallery"+p_n+".json"
        $.getJSON(json_page_url, function(data){
            var r= 0
            $.each( data, function( id, element ) {
                if(id && element && element.type && element.url){
                    var a=$("<a class=\"gallery-element\" id=\""+id+"\" src=\""+element.url+"\" src-type=\""+element.type+"\"></a>").appendTo($parent)
                    if(element.description && element.description.length>0){
                        $("<span hidden class=\"gallery-element-description\">"+element.description+"</span>").appendTo($(a))
                    }
                    if(element.timestamp && element.timestamp.length>0){
                        $("<time hidden class=\"gallery-element-timestamp\">"+element.timestamp+"</time>").appendTo($(a))
                    }
                }
            });

            _add_btn($parent, p_n, num_pages)

            done()
        });



        window.history.pushState({"page": p_n}, 'Gallery page '+p_n, "?page="+p_n)
    })
}
