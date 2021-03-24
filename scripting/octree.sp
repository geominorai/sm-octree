#pragma semicolon 1
#pragma newdecls required

#define DEBUG

#define PLUGIN_AUTHOR "AI"
#define PLUGIN_VERSION "0.1.1"

#include <sourcemod>
#include <octree>

public Plugin myinfo = {
	name = "Octree",
	author = PLUGIN_AUTHOR,
	description = "Octree implementation in SourcePawn",
	version = PLUGIN_VERSION,
	url = "https://github.com/geominorai/sm-octree"
};

public void OnPluginStart() {
	CreateConVar("sm_octree_version", PLUGIN_VERSION, "Octree version -- Do not modify", FCVAR_NOTIFY | FCVAR_DONTRECORD);
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int sErrMax) {
	RegPluginLibrary("octree");

	CreateNative("OctNode.fHalfWidth.get",		Native_OctNode_GetHalfWidth);
	CreateNative("OctNode.iDepth.get",			Native_OctNode_GetDepth);
	CreateNative("OctNode.iParent.get",			Native_OctNode_GetParent);
	CreateNative("OctNode.hBuffer.get",			Native_OctNode_GetBuffer);
	CreateNative("OctNode.bLeaf.get",			Native_OctNode_GetLeaf);
	CreateNative("OctNode.aData.get",			Native_OctNode_GetData);
	CreateNative("OctNode.aData.set",			Native_OctNode_SetData);
	CreateNative("OctNode.GetCenter",			Native_OctNode_GetCenter);
	CreateNative("OctNode.GetBranch",			Native_OctNode_GetBranch);
	CreateNative("OctNode.GetNearestBranch",	Native_OctNode_GetNearestBranch);
	CreateNative("OctNode.Insert",				Native_OctNode_Insert);
	CreateNative("OctNode.Find",				Native_OctNode_Find);
	CreateNative("OctNode.Instance",			Native_OctNode_Instance);
	CreateNative("OctNode.Destroy",				Native_OctNode_Destroy);

	CreateNative("Octree.iSize.get",			Native_Octree_GetSize);
	CreateNative("Octree.GetCenter",			Native_Octree_GetCenter);
	CreateNative("Octree.Insert",				Native_Octree_Insert);
	CreateNative("Octree.Find",					Native_Octree_Find);
	CreateNative("Octree.Instance",				Native_Octree_Instance);
	CreateNative("Octree.Destroy",				Native_Octree_Destroy);
}

// class OctNode

enum struct _OctNode {
	float fCenter[3];
	float fHalfWidth;
	int iDepth;
	OctNode iParent;
	ArrayList hBuffer;
	int iBufferSize;
	any aData;
	OctNode iBranches[8];
	bool bGCFlag;
}

enum struct _OctItem {
	float fPos[3];
	any aData;
}

static ArrayList hOctNodes = null;
static int iOctNodeAlloc = 0;

public int Native_OctNode_GetHalfWidth(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	return hOctNodes.Get(iThis, _OctNode::fHalfWidth);
}

public int Native_OctNode_GetDepth(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	return hOctNodes.Get(iThis, _OctNode::iDepth);
}

public int Native_OctNode_GetParent(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	return hOctNodes.Get(iThis, _OctNode::iParent);
}

public int Native_OctNode_GetBuffer(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	return hOctNodes.Get(iThis, _OctNode::hBuffer);
}

public int Native_OctNode_GetLeaf(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	return view_as<ArrayList>(hOctNodes.Get(iThis, _OctNode::hBuffer)) != null;
}

public int Native_OctNode_GetData(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	return hOctNodes.Get(iThis, _OctNode::aData);
}

public int Native_OctNode_SetData(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;
	any aData = GetNativeCell(2);

	hOctNodes.Set(iThis, aData, _OctNode::aData);
}

public int Native_OctNode_GetCenter(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	float fCenter[3];
	hOctNodes.GetArray(iThis, fCenter, sizeof(fCenter));

	SetNativeArray(2, fCenter, sizeof(fCenter));
}

public any Native_OctNode_GetBranch(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;
	int iOctant = GetNativeCell(2);
	bool bAutoCreate = GetNativeCell(3) != 0;

	OctNode iBranchNode = hOctNodes.Get(iThis, _OctNode::iBranches + iOctant);
	if (!iBranchNode && bAutoCreate) {
		int iBufferSize = hOctNodes.Get(iThis, _OctNode::iBufferSize);

		float fCenter[3];
		hOctNodes.GetArray(iThis, fCenter, sizeof(fCenter));

		float fHalfWidth = 0.5 * view_as<float>(hOctNodes.Get(iThis, _OctNode::fHalfWidth));

		fCenter[0] += iOctant & 4 ? fHalfWidth : -fHalfWidth;
		fCenter[1] += iOctant & 2 ? fHalfWidth : -fHalfWidth;
		fCenter[2] += iOctant & 1 ? fHalfWidth : -fHalfWidth;

		iBranchNode = OctNode.Instance(view_as<OctNode>(iThis+1), fCenter, fHalfWidth, iBufferSize);
		hOctNodes.Set(iThis, iBranchNode, _OctNode::iBranches + iOctant);
	}

	return iBranchNode;
}

public any Native_OctNode_GetNearestBranch(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	float fPos[3];
	GetNativeArray(2, fPos, sizeof(fPos));

	bool bAutoCreate = GetNativeCell(3) != 0;

	float fCenter[3];
	hOctNodes.GetArray(iThis, fCenter, sizeof(fCenter));

	int iOctant = view_as<int>(fPos[0] >= fCenter[0]) << 2 | view_as<int>(fPos[1] >= fCenter[1]) << 1 | view_as<int>(fPos[2] >= fCenter[2]);

	OctNode iBranchNode = hOctNodes.Get(iThis, _OctNode::iBranches + iOctant);
	if (!iBranchNode && bAutoCreate) {
		int iBufferSize = hOctNodes.Get(iThis, _OctNode::iBufferSize);

		float fHalfWidth = 0.5 * view_as<float>(hOctNodes.Get(iThis, _OctNode::fHalfWidth));

		fCenter[0] += iOctant & 4 ? fHalfWidth : -fHalfWidth;
		fCenter[1] += iOctant & 2 ? fHalfWidth : -fHalfWidth;
		fCenter[2] += iOctant & 1 ? fHalfWidth : -fHalfWidth;

		iBranchNode = OctNode.Instance(view_as<OctNode>(iThis+1), fCenter, fHalfWidth, iBufferSize);
		hOctNodes.Set(iThis, iBranchNode, _OctNode::iBranches + iOctant);
	}

	return iBranchNode;
}

public int Native_OctNode_Insert(Handle hPlugin, int iArgC) {
	OctNode iOctNode = GetNativeCell(1);

	float fPos[3];
	GetNativeArray(2, fPos, sizeof(fPos));

	any aData = GetNativeCell(3);

	ArrayList hBuffer = iOctNode.hBuffer;
	if (hBuffer) {
		_OctItem eItem;
		eItem.fPos = fPos;
		eItem.aData = aData;
		hBuffer.PushArray(eItem);

		int iBufferSize = hOctNodes.Get(view_as<int>(iOctNode)-1, _OctNode::iBufferSize);

		int iBufferLength = hBuffer.Length;
		if (iBufferLength > iBufferSize) {
			for (int i=0; i<iBufferLength; i++) {
				hBuffer.GetArray(i, eItem);

				OctNode iBranchNode = iOctNode.GetNearestBranch(eItem.fPos, true);
				iBranchNode.Insert(eItem.fPos, eItem.aData);
			}

			delete hBuffer;
			hOctNodes.Set(view_as<int>(iOctNode)-1, 0, _OctNode::hBuffer);
		}
	} else {
		OctNode iBranchNode = iOctNode.GetNearestBranch(fPos, true);
		iBranchNode.Insert(fPos, aData);
	}
}

public int Native_OctNode_Find(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	float fPos[3];
	GetNativeArray(2, fPos, sizeof(fPos));

	float fRadius = GetNativeCell(3);
	ArrayList hFound = GetNativeCell(4);

	float fHalfWidth = view_as<float>(hOctNodes.Get(iThis, _OctNode::fHalfWidth));

	float fCenter[3];
	hOctNodes.GetArray(iThis, fCenter, sizeof(fCenter));

	float fPosShift[3];
	SubtractVectors(fPos, fCenter, fPosShift);

	// AABB and query sphere overlap tests

	if (fPosShift[0] > fHalfWidth && fPosShift[1] > fHalfWidth && fPosShift[2] > fHalfWidth) {
		fPosShift[0] -= fHalfWidth;
		fPosShift[1] -= fHalfWidth;
		fPosShift[2] -= fHalfWidth;

		if (GetVectorLength(fPosShift) > fRadius) {
			return 0;
		}
	}

	int iTotal;

	ArrayList hBuffer = hOctNodes.Get(iThis, _OctNode::hBuffer);
	if (hBuffer) {
		_OctItem eItem;

		for (int i=0; i<hBuffer.Length; i++) {
			hBuffer.GetArray(i, eItem);

			if (GetVectorDistance(fPos, eItem.fPos) < fRadius) {
				hFound.PushArray(eItem);
				iTotal++;
			}
		}
	} else {
		for (int i=0; i<8; i++) {
			OctNode iBranchNode = hOctNodes.Get(iThis, _OctNode::iBranches + i);
			if (iBranchNode) {
				iTotal += iBranchNode.Find(fPos, fRadius, hFound);
			}
		}
	}

	return iTotal;
}

public int Native_OctNode_Instance(Handle hPlugin, int iArgC) {
	if (hOctNodes == null) {
		hOctNodes = new ArrayList(sizeof(_OctNode));
	}

	OctNode iParent = GetNativeCell(1);

	float fCenter[3];
	GetNativeArray(2, fCenter, sizeof(fCenter));

	float fHalfWidth = GetNativeCell(3);
	int iBufferSize = GetNativeCell(4);

	_OctNode eOctNode;
	eOctNode.fCenter = fCenter;
	eOctNode.fHalfWidth = fHalfWidth;
	eOctNode.iParent = iParent;
	eOctNode.hBuffer = new ArrayList(sizeof(_OctItem));
	eOctNode.iBufferSize = iBufferSize;

	if (iParent) {
		eOctNode.iDepth = hOctNodes.Get(view_as<int>(iParent)-1, _OctNode::iDepth) + 1;
	}

	for (int i=0; i<hOctNodes.Length; i++) {
		if (hOctNodes.Get(i, _OctNode::bGCFlag)) {
			hOctNodes.SetArray(i, eOctNode);

			return i+1;
		}
	}

	return iOctNodeAlloc = hOctNodes.PushArray(eOctNode) + 1;
}

public int Native_OctNode_Destroy(Handle hPlugin, int iArgC) {
	if (hOctNodes != null) {
		int iOctNodeIdx = GetNativeCellRef(1)-1;
		if (iOctNodeIdx <= 0) {
			return;
		}

		hOctNodes.Set(iOctNodeIdx, 1, _OctNode::bGCFlag);
		delete view_as<ArrayList>(hOctNodes.Get(iOctNodeIdx, _OctNode::hBuffer));

		for (int i=0; i<8; i++) {
			OctNode iBranchNode = hOctNodes.Get(iOctNodeIdx, _OctNode::iBranches+i);
			OctNode.Destroy(iBranchNode);
		}

		SetNativeCellRef(1, NULL_OCTNODE);

		if (iOctNodeIdx+1 == iOctNodeAlloc) {
			for (int i=iOctNodeAlloc-1; i>0; i++) {
				if (!hOctNodes.Get(i-1, _OctNode::bGCFlag)) {
					hOctNodes.Resize(iOctNodeAlloc = i);
					return;
				}
			}

			hOctNodes.Clear();
		}
	}
}

// class Octree

enum struct _Octree {
	float fCenter[3];
	float fHalfWidth;
	OctNode iRootNode;
	int iSize;
	int iBufferSize;
	bool bGCFlag;
}

static ArrayList hOctrees = null;
static int iOctreeAlloc = 0;

public int Native_Octree_GetSize(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;
	return hOctrees.Get(iThis, _Octree::iSize);
}

public int Native_Octree_GetCenter(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;
	float fCenter[3];
	hOctrees.GetArray(iThis, fCenter, sizeof(fCenter));

	SetNativeArray(2, fCenter, sizeof(fCenter));
}

public int Native_Octree_Insert(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	float fPos[3];
	GetNativeArray(2, fPos, sizeof(fPos));

	any aData = GetNativeCell(3);

	OctNode iRootNode = hOctrees.Get(iThis, _Octree::iRootNode);
	iRootNode.Insert(fPos, aData);

	int iSize = hOctrees.Get(iThis, _Octree::iSize);
	hOctrees.Set(iThis, iSize+1, _Octree::iSize);
}

public int Native_Octree_Find(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	float fPos[3];
	GetNativeArray(2, fPos, sizeof(fPos));

	float fRadius = GetNativeCell(3);
	ArrayList hResult = GetNativeCell(4);
	bool bSort = GetNativeCell(5);

	ArrayList hFound = new ArrayList(sizeof(_OctItem));

	OctNode iRootNode = hOctrees.Get(iThis, _Octree::iRootNode);
	int iTotal = iRootNode.Find(fPos, fRadius, hFound);

	if (bSort) {
		ArrayList hData = new ArrayList(sizeof(fPos));
		hData.PushArray(fPos);
		SortADTArrayCustom(hFound, SortFunc_Distance, hData);
		delete hData;
	}

	for (int i=0; i<iTotal; i++) {
		hResult.Push(hFound.Get(i, _OctItem::aData));
	}

	delete hFound;

	return iTotal;
}

public int Native_Octree_Instance(Handle hPlugin, int iArgC) {
	float fCenter[3];
	GetNativeArray(1, fCenter, sizeof(fCenter));

	float fHalfWidth = GetNativeCell(2);

	if (hOctrees == null) {
		hOctrees = new ArrayList(sizeof(_Octree));
	}

	int iBufferSize = GetNativeCell(3);

	OctNode iRootNode = OctNode.Instance(NULL_OCTNODE, fCenter, fHalfWidth, iBufferSize);

	_Octree eOctree;
	eOctree.fCenter = fCenter;
	eOctree.fHalfWidth = fHalfWidth;
	eOctree.iRootNode = iRootNode;
	eOctree.iBufferSize = iBufferSize;

	for (int i=0; i<hOctrees.Length; i++) {
		if (hOctrees.Get(i, _Octree::bGCFlag)) {
			hOctrees.SetArray(i, eOctree);

			return i+1;
		}
	}

	return iOctreeAlloc = hOctrees.PushArray(eOctree) + 1;
}

public int Native_Octree_Destroy(Handle hPlugin, int iArgC) {
	if (hOctrees != null) {
		int iOctree = GetNativeCellRef(1)-1;
		if (iOctree <= 0) {
			return;
		}

		hOctrees.Set(iOctree, 1, _Octree::bGCFlag);

		OctNode iRootNode = view_as<OctNode>(hOctrees.Get(iOctree, _Octree::iRootNode));
		OctNode.Destroy(iRootNode);

		SetNativeCellRef(1, NULL_OCTREE);

		if (iOctree+1 == iOctreeAlloc) {
			for (int i=iOctreeAlloc-1; i>0; i++) {
				if (!hOctrees.Get(i-1, _Octree::bGCFlag)) {
					hOctrees.Resize(iOctreeAlloc = i);
					return;
				}
			}

			hOctrees.Clear();
		}
	}
}

// Callbacks

int SortFunc_Distance(int iIdx1, int iIdx2, Handle hArray, Handle hHndl) {
	ArrayList hList = view_as<ArrayList>(hArray);
	ArrayList hData = view_as<ArrayList>(hHndl);

	float fPosProbe[3], fPos1[3], fPos2[3];
	hData.GetArray(0, fPosProbe);
	hList.GetArray(iIdx1, fPos1, sizeof(fPos1));
	hList.GetArray(iIdx2, fPos2, sizeof(fPos2));

	return GetVectorDistance(fPosProbe, fPos1) < GetVectorDistance(fPosProbe, fPos2) ? -1 : 1;
}
