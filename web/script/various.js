var windw= null

function various_setWindw(w){
    windw= w
}

$.fn.followWithinParent = function () {
    var $this = this,
        $window = $(windw);

    var $parent= $this.parent()

    $this.css({
        width: $parent.innerWidth()-parseInt($parent.css('padding-left'))
    })
    
    $window.resize(function(){
        $this.css({
            width: $parent.innerWidth()-parseInt($parent.css('padding-left'))
        })
    })
    
    $window.scroll(function(e){
        var parentTop= $parent.position().top
        var parentPaddingTop= parseInt($parent.css('padding-top'))
        var pos= $parent.outerHeight()-$this.outerHeight()-parentPaddingTop-parseInt($parent.css('padding-bottom'))

        if ($window.scrollTop() > pos) {
            $this.css({
                position: 'absolute',
                top: pos+parentTop+parentPaddingTop
            });
        } else {
            $this.css({
                position: 'fixed',
                top: parentTop+parentPaddingTop
            });
        }
    });
};

$.fn.populateAsToC= function($source){
    var $target = this,
        $window = $(windw);

    $source.children('h1, h2, h3').each(function(index){
        var $n_link= $('<a href="#'+$( this ).attr("id")+'"></a>').appendTo($target)
        $( this ).clone().appendTo($n_link).attr("id",$( this ).attr("id")+"_toc")
    })
}