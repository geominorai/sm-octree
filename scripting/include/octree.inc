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
	MarkNativeAsOptional("OctNode.mParent.get");
	MarkNativeAsOptional("OctNode.hBuffer.get");
	MarkNativeAsOptional("OctNode.bLeaf.get");
	MarkNativeAsOptional("OctNode.aData.get");
	MarkNativeAsOptional("OctNode.aData.set");
	MarkNativeAsOptional("OctNode.GetCenter");
	MarkNativeAsOptional("OctNode.GetBranch");
	MarkNativeAsOptional("OctNode.GetNearestBranch");
	MarkNativeAsOptional("OctNode.Contains");
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

	property OctNode mParent {
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

	public native void GetCenter(float vecCenter[3]);
	public native void GetBounds(float vecMins[3], float vecMaxs[3]);
	public native OctNode GetBranch(int iOctant, bool bAutoCreate=false);
	public native OctNode GetNearestBranch(float vecPos[3], bool bAutoCreate=false);

	public native bool Contains(float vecPos[3]);

	public native void Insert(float vecPos[3], any aData);
	public native int Find(float vecPos[3], float fRadius, ArrayList hResult);

	public static native OctNode Instance(OctNode mParentNode, float vecCenter[3], float fHalfWidth, int iBufferSize=50);
	public static native void Destroy(OctNode &mNode);
}

methodmap Octree {
	property int iSize {
		public native get();
	}

	public native void GetCenter(float vecCenter[3]);
	public native void GetBounds(float vecMins[3], float vecMaxs[3]);

	public native bool Contains(float vecPos[3]);

	public native void Insert(float vecPos[3], any aData);
	public native int Find(float vecPos[3], float fRadius, ArrayList hResult, bool bSort=false, bool bIncludePos=false, int iMaxResults=-1);

	public static native Octree Instance(float vecCenter[3], float fHalfWidth, int iBufferSize=50);
	public static native void Destroy(Octree &mOctree);
}

enum struct OctItem {
	float vecPos[3];
	any aData;
}

#define NULL_OCTNODE	view_as<OctNode>(0)
#define NULL_OCTREE		view_as<Octree>(0)
