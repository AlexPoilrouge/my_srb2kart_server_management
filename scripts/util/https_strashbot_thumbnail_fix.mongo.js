db.clips.find().forEach(obj =>{
	var thumb= obj.thumbnail;
	if (thumb.startsWith('http://strashbot.fr/kart/clip_thumbnails')){
		//printjson(obj._id);
		var newthumb = thumb.replace(/^http:/,'https:');
		db.clips.updateOne({_id: obj._id},{$set:{"thumbnail": newthumb }});
	}
})