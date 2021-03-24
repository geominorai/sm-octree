#if defined _OCTREE_included
 #endinput
#endif
#define _OCTREE_included

public SharedPlugin __pl_octree = {
	name = "octree",
	file = "octree.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_octree_SetNTVOptional() {
	MarkNativeAsOptional("OctNode.fHalfWidth.get");
	MarkNativeAsOptional("OctNode.iDepth.get");
	MarkNativeAsOptional("OctNode.iParent.get");
	MarkNativeAsOptional("OctNode.hBuffer.get");
	MarkNativeAsOptional("OctNode.bLeaf.get");
	MarkNativeAsOptional("OctNode.aData.get");
	MarkNativeAsOptional("OctNode.aData.set");
	MarkNativeAsOptional("OctNode.GetCenter");
	MarkNativeAsOptional("OctNode.GetBranch");
	MarkNativeAsOptional("OctNode.GetNearestBranch");
	MarkNativeAsOptional("OctNode.Insert");
	MarkNativeAsOptional("OctNode.Find");
	MarkNativeAsOptional("OctNode.Instance");
	MarkNativeAsOptional("OctNode.Destroy");

	MarkNativeAsOptional("Octree.iSize.get");
	MarkNativeAsOptional("Octree.GetCenter");
	MarkNativeAsOptional("Octree.Insert");
	MarkNativeAsOptional("Octree.Find");
	MarkNativeAsOptional("Octree.Instance");
	MarkNativeAsOptional("Octree.Destroy");
}
#endif

methodmap OctNode {
	property float fHalfWidth {
		public native get();
	}

	property int iDepth {
		public native get();
	}

	property OctNode iParent {
		public native get();
	}

	property ArrayList hBuffer {
		public native get();
	}

	property bool bLeaf {
		public native get();
	}

	property any bData {
		public native get();
		public native set(any aData);
	}

	public native void GetCenter(float fCenter[3]);
	public native OctNode GetBranch(int iOctant, bool bAutoCreate=false);
	public native OctNode GetNearestBranch(float fPos[3], bool bAutoCreate=false);

	public native void Insert(float fPos[3], any aData);
	public native int Find(float fPos[3], float fRadius, ArrayList hResult);

	public static native OctNode Instance(OctNode iParentNode, float fCenter[3], float fHalfWidth, int iBufferSize=50);
	public static native void Destroy(OctNode &iNode);
}

methodmap Octree {
	property int iSize {
		public native get();
	}

	public native void GetCenter(float fCenter[3]);

	public native void Insert(float fPos[3], any aData);
	public native int Find(float fPos[3], float fRadius, ArrayList hResult, bool bSort=false);

	public static native Octree Instance(float fCenter[3], float fHalfWidth, int iBufferSize=50);
	public static native void Destroy(Octree &iOctree);
}

#define NULL_OCTNODE	view_as<OctNode>(0)
#define NULL_OCTREE		view_as<Octree>(0)
