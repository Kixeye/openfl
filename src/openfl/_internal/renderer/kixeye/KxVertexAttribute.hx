package openfl._internal.renderer.kixeye;

class KxVertexAttribute
{
	public var name:String;
	public var size:Int;
	public var normalize:Bool;

	public function new(name:String, size:Int, normalize:Bool)
	{
		this.name = name;
		this.size = size;
		this.normalize = normalize;
	}
}
