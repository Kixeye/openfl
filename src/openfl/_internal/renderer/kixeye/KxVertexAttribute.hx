package openfl._internal.renderer.kixeye;

class KxVertexAttribute
{
	public var name:String;
	public var size:Int;
	public var norm:Bool;

	public function new(name:String, size:Int, norm:Bool)
	{
		this.name = name;
		this.size = size;
		this.norm = norm;
	}
}
