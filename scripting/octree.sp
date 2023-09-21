#pragma semicolon 1
#pragma newdecls required

#define DEBUG

#define PLUGIN_AUTHOR "AI"
#define PLUGIN_VERSION "0.2.0"

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
	CreateNative("OctNode.mParent.get",			Native_OctNode_GetParent);
	CreateNative("OctNode.hBuffer.get",			Native_OctNode_GetBuffer);
	CreateNative("OctNode.bLeaf.get",			Native_OctNode_GetLeaf);
	CreateNative("OctNode.aData.get",			Native_OctNode_GetData);
	CreateNative("OctNode.aData.set",			Native_OctNode_SetData);
	CreateNative("OctNode.GetCenter",			Native_OctNode_GetCenter);
	CreateNative("OctNode.GetBounds",			Native_OctNode_GetBounds);
	CreateNative("OctNode.GetBranch",			Native_OctNode_GetBranch);
	CreateNative("OctNode.GetNearestBranch",	Native_OctNode_GetNearestBranch);
	CreateNative("OctNode.Contains",			Native_OctNode_Contains);
	CreateNative("OctNode.Insert",				Native_OctNode_Insert);
	CreateNative("OctNode.Find",				Native_OctNode_Find);
	CreateNative("OctNode.Instance",			Native_OctNode_Instance);
	CreateNative("OctNode.Destroy",				Native_OctNode_Destroy);

	CreateNative("Octree.iSize.get",			Native_Octree_GetSize);
	CreateNative("Octree.GetCenter",			Native_Octree_GetCenter);
	CreateNative("Octree.GetBounds",			Native_Octree_GetBounds);
	CreateNative("Octree.Contains",				Native_Octree_Contains);
	CreateNative("Octree.Insert",				Native_Octree_Insert);
	CreateNative("Octree.Find",					Native_Octree_Find);
	CreateNative("Octree.Instance",				Native_Octree_Instance);
	CreateNative("Octree.Destroy",				Native_Octree_Destroy);

	return APLRes_Success;
}

// class OctNode

enum struct _OctNode {
	float vecCenter[3];
	float fHalfWidth;
	OctNode mParent;
	ArrayList hBuffer;
	int iBufferSize;
	any aData;
	OctNode mBranches[8];
	bool bGCFlag;
}

static ArrayList m_hOctNodes = null;
static int m_iOctNodeAlloc = 0;

public int Native_OctNode_GetHalfWidth(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	return m_hOctNodes.Get(iThis, _OctNode::fHalfWidth);
}

public int Native_OctNode_GetDepth(Handle hPlugin, int iArgC) {
	int iDepth;
	OctNode mOctNode = GetNativeCell(1);
	while (mOctNode) {
		iDepth++;
		mOctNode = mOctNode.mParent;
	}

	return iDepth;
}

public int Native_OctNode_GetParent(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	return m_hOctNodes.Get(iThis, _OctNode::mParent);
}

public int Native_OctNode_GetBuffer(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	return m_hOctNodes.Get(iThis, _OctNode::hBuffer);
}

public int Native_OctNode_GetLeaf(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	return view_as<ArrayList>(m_hOctNodes.Get(iThis, _OctNode::hBuffer)) != null;
}

public int Native_OctNode_GetData(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	return m_hOctNodes.Get(iThis, _OctNode::aData);
}

public int Native_OctNode_SetData(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;
	any aData = GetNativeCell(2);

	m_hOctNodes.Set(iThis, aData, _OctNode::aData);

	return 0;
}

public int Native_OctNode_GetCenter(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	float vecCenter[3];
	m_hOctNodes.GetArray(iThis, vecCenter, sizeof(vecCenter));

	SetNativeArray(2, vecCenter, sizeof(vecCenter));

	return 0;
}

public int Native_OctNode_GetBounds(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	float vecCenter[3];
	m_hOctNodes.GetArray(iThis, vecCenter, sizeof(vecCenter));

	float fHalfWidth = m_hOctNodes.Get(iThis, _OctNode::fHalfWidth);

	float vecMins[3], vecMaxs[3];
	vecMins[0] = vecCenter[0] - fHalfWidth;
	vecMins[1] = vecCenter[1] - fHalfWidth;
	vecMins[2] = vecCenter[2] - fHalfWidth;

	vecMaxs[0] = vecCenter[0] + fHalfWidth;
	vecMaxs[1] = vecCenter[1] + fHalfWidth;
	vecMaxs[2] = vecCenter[2] + fHalfWidth;

	SetNativeArray(2, vecMins, sizeof(vecMins));
	SetNativeArray(3, vecMaxs, sizeof(vecMaxs));

	return 0;
}

public any Native_OctNode_GetBranch(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;
	int iOctant = GetNativeCell(2);
	bool bAutoCreate = GetNativeCell(3) != 0;

	OctNode mBranchNode = m_hOctNodes.Get(iThis, _OctNode::mBranches + iOctant);
	if (!mBranchNode && bAutoCreate) {
		int iBufferSize = m_hOctNodes.Get(iThis, _OctNode::iBufferSize);

		float vecCenter[3];
		m_hOctNodes.GetArray(iThis, vecCenter, sizeof(vecCenter));

		float fHalfWidth = 0.5 * view_as<float>(m_hOctNodes.Get(iThis, _OctNode::fHalfWidth));

		vecCenter[0] += iOctant & 4 ? fHalfWidth : -fHalfWidth;
		vecCenter[1] += iOctant & 2 ? fHalfWidth : -fHalfWidth;
		vecCenter[2] += iOctant & 1 ? fHalfWidth : -fHalfWidth;

		mBranchNode = OctNode.Instance(view_as<OctNode>(iThis+1), vecCenter, fHalfWidth, iBufferSize);
		m_hOctNodes.Set(iThis, mBranchNode, _OctNode::mBranches + iOctant);
	}

	return mBranchNode;
}

public any Native_OctNode_GetNearestBranch(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	float vecPos[3];
	GetNativeArray(2, vecPos, sizeof(vecPos));

	bool bAutoCreate = GetNativeCell(3) != 0;

	float vecCenter[3];
	m_hOctNodes.GetArray(iThis, vecCenter, sizeof(vecCenter));

	int iOctant = view_as<int>(vecPos[0] >= vecCenter[0]) << 2 | view_as<int>(vecPos[1] >= vecCenter[1]) << 1 | view_as<int>(vecPos[2] >= vecCenter[2]);

	OctNode mBranchNode = m_hOctNodes.Get(iThis, _OctNode::mBranches + iOctant);
	if (!mBranchNode && bAutoCreate) {
		int iBufferSize = m_hOctNodes.Get(iThis, _OctNode::iBufferSize);

		float fHalfWidth = 0.5 * view_as<float>(m_hOctNodes.Get(iThis, _OctNode::fHalfWidth));

		vecCenter[0] += iOctant & 4 ? fHalfWidth : -fHalfWidth;
		vecCenter[1] += iOctant & 2 ? fHalfWidth : -fHalfWidth;
		vecCenter[2] += iOctant & 1 ? fHalfWidth : -fHalfWidth;

		mBranchNode = OctNode.Instance(view_as<OctNode>(iThis+1), vecCenter, fHalfWidth, iBufferSize);
		m_hOctNodes.Set(iThis, mBranchNode, _OctNode::mBranches + iOctant);
	}

	return mBranchNode;
}

public any Native_OctNode_Contains(Handle hPlugin, int iArgC) {
	OctNode mOctNode = GetNativeCell(1);

	float vecPos[3];
	GetNativeArray(2, vecPos, sizeof(vecPos));

	float fHalfWidth = mOctNode.fHalfWidth;

	float vecCenter[3];
	mOctNode.GetCenter(vecCenter);

	return
		(vecCenter[0] - fHalfWidth <= vecPos[0] < vecCenter[0] + fHalfWidth) &&
		(vecCenter[1] - fHalfWidth <= vecPos[1] < vecCenter[1] + fHalfWidth) &&
		(vecCenter[2] - fHalfWidth <= vecPos[2] < vecCenter[2] + fHalfWidth);
}

public int Native_OctNode_Insert(Handle hPlugin, int iArgC) {
	OctNode mOctNode = GetNativeCell(1);

	float vecPos[3];
	GetNativeArray(2, vecPos, sizeof(vecPos));

	if (!mOctNode.Contains(vecPos)) {
		float vecMins[3], vecMaxs[3];
		mOctNode.GetBounds(vecMins, vecMaxs);

		ThrowError(
			"Point [%.1f, %.1f, %.1f] is out of bounds (mins: [%.1f, %.1f, %.1f], maxs: [%.1f, %.1f, %.1f])",
			vecPos[0], vecPos[1], vecPos[2],
			vecMins[0], vecMins[1], vecMins[2],
			vecMaxs[0], vecMaxs[1], vecMaxs[2]
		);
	}

	any aData = GetNativeCell(3);

	ArrayList hBuffer = mOctNode.hBuffer;
	if (hBuffer) {
		OctItem eItem;
		eItem.vecPos = vecPos;
		eItem.aData = aData;
		hBuffer.PushArray(eItem);

		int iBufferSize = m_hOctNodes.Get(view_as<int>(mOctNode)-1, _OctNode::iBufferSize);

		int iBufferLength = hBuffer.Length;
		if (iBufferLength > iBufferSize) {
			for (int i=0; i<iBufferLength; i++) {
				hBuffer.GetArray(i, eItem);

				OctNode mBranchNode = mOctNode.GetNearestBranch(eItem.vecPos, true);
				mBranchNode.Insert(eItem.vecPos, eItem.aData);
			}

			delete hBuffer;
			m_hOctNodes.Set(view_as<int>(mOctNode)-1, 0, _OctNode::hBuffer);
		}
	} else {
		OctNode mBranchNode = mOctNode.GetNearestBranch(vecPos, true);
		mBranchNode.Insert(vecPos, aData);
	}

	return 0;
}

public int Native_OctNode_Find(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	_OctNode eOctNode;
	m_hOctNodes.GetArray(iThis, eOctNode);

	float vecPos[3];
	GetNativeArray(2, vecPos, sizeof(vecPos));

	float fRadius = GetNativeCell(3);
	ArrayList hFound = GetNativeCell(4);

	float vecPosShift[3];
	vecPosShift[0] = FloatAbs(vecPos[0]-eOctNode.vecCenter[0]);
	vecPosShift[1] = FloatAbs(vecPos[1]-eOctNode.vecCenter[1]);
	vecPosShift[2] = FloatAbs(vecPos[2]-eOctNode.vecCenter[2]);

	float fRange = eOctNode.fHalfWidth + fRadius;

	// AABB and query sphere overlap tests: max_j(q'[j]) < e+r  -->  q'[j] <= q'[ max_j(q'[j]) ] < e+r

	if (vecPosShift[0] >= fRange || vecPosShift[1] >= fRange || vecPosShift[2] >= fRange) {
		return 0;
	}

	int iTotal;

	ArrayList hBuffer = eOctNode.hBuffer;
	if (hBuffer) {
		OctItem eItem;

		int iBufferLength = hBuffer.Length;
		for (int i=0; i<iBufferLength; i++) {
			hBuffer.GetArray(i, eItem);

			if (GetVectorDistance(vecPos, eItem.vecPos) < fRadius) {
				hFound.PushArray(eItem);
				iTotal++;
			}
		}
	} else {
		OctNode mBranchNode;

		for (int i=0; i<8; i++) {
			mBranchNode = eOctNode.mBranches[i];
			if (mBranchNode) {
				iTotal += mBranchNode.Find(vecPos, fRadius, hFound);
			}
		}
	}

	return iTotal;
}

public int Native_OctNode_Instance(Handle hPlugin, int iArgC) {
	if (m_hOctNodes == null) {
		m_hOctNodes = new ArrayList(sizeof(_OctNode));
	}

	OctNode mParent = GetNativeCell(1);

	float vecCenter[3];
	GetNativeArray(2, vecCenter, sizeof(vecCenter));

	float fHalfWidth = GetNativeCell(3);
	int iBufferSize = GetNativeCell(4);

	_OctNode eOctNode;
	eOctNode.vecCenter = vecCenter;
	eOctNode.fHalfWidth = fHalfWidth;
	eOctNode.mParent = mParent;
	eOctNode.hBuffer = new ArrayList(sizeof(OctItem));
	eOctNode.iBufferSize = iBufferSize;

	int iOctNodesLength = m_hOctNodes.Length;
	for (int i=0; i<iOctNodesLength; i++) {
		if (m_hOctNodes.Get(i, _OctNode::bGCFlag)) {
			m_hOctNodes.SetArray(i, eOctNode);

			return i+1;
		}
	}

	return m_iOctNodeAlloc = m_hOctNodes.PushArray(eOctNode) + 1;
}

public int Native_OctNode_Destroy(Handle hPlugin, int iArgC) {
	if (m_hOctNodes != null) {
		int mOctNodeIdx = GetNativeCellRef(1)-1;
		if (mOctNodeIdx < 0) {
			return 0;
		}

		for (int i=0; i<8; i++) {
			OctNode mBranchNode = m_hOctNodes.Get(mOctNodeIdx, _OctNode::mBranches+i);
			OctNode.Destroy(mBranchNode);
		}

		m_hOctNodes.Set(mOctNodeIdx, 1, _OctNode::bGCFlag);
		delete view_as<ArrayList>(m_hOctNodes.Get(mOctNodeIdx, _OctNode::hBuffer));

		SetNativeCellRef(1, NULL_OCTNODE);

		if (mOctNodeIdx+1 == m_iOctNodeAlloc) {
			for (int i=mOctNodeIdx; i>0; i--) {
				if (!m_hOctNodes.Get(i-1, _OctNode::bGCFlag)) {
					m_hOctNodes.Resize(m_iOctNodeAlloc = i);
					return 0;
				}
			}

			m_hOctNodes.Clear();
			m_iOctNodeAlloc = 0;
		}
	}

	return 0;
}

// class Octree

enum struct _Octree {
	float vecCenter[3];
	float fHalfWidth;
	OctNode mRootNode;
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
	float vecCenter[3];
	hOctrees.GetArray(iThis, vecCenter, sizeof(vecCenter));

	SetNativeArray(2, vecCenter, sizeof(vecCenter));

	return 0;
}

public int Native_Octree_GetBounds(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	OctNode mRootNode = hOctrees.Get(iThis, _Octree::mRootNode);

	float vecMins[3], vecMaxs[3];
	mRootNode.GetBounds(vecMins, vecMaxs);

	SetNativeArray(2, vecMins, sizeof(vecMins));
	SetNativeArray(3, vecMaxs, sizeof(vecMaxs));

	return 0;
}

public any Native_Octree_Contains(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	OctNode mRootNode = hOctrees.Get(iThis, _Octree::mRootNode);

	float vecPos[3];
	GetNativeArray(2, vecPos, sizeof(vecPos));

	return mRootNode.Contains(vecPos);
}

public int Native_Octree_Insert(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	float vecPos[3];
	GetNativeArray(2, vecPos, sizeof(vecPos));

	any aData = GetNativeCell(3);

	OctNode mRootNode = hOctrees.Get(iThis, _Octree::mRootNode);
	mRootNode.Insert(vecPos, aData);

	int iSize = hOctrees.Get(iThis, _Octree::iSize);
	hOctrees.Set(iThis, iSize+1, _Octree::iSize);

	return 0;
}

public int Native_Octree_Find(Handle hPlugin, int iArgC) {
	int iThis = GetNativeCell(1)-1;

	float vecPosProbe[3];
	GetNativeArray(2, vecPosProbe, sizeof(vecPosProbe));

	float fRadius = GetNativeCell(3);
	ArrayList hResult = GetNativeCell(4);
	bool bSort = GetNativeCell(5);
	bool bIncludePos = GetNativeCell(6);
	int iMaxResults = GetNativeCell(7);

	ArrayList hFound = new ArrayList(sizeof(OctItem));

	OctNode mRootNode = hOctrees.Get(iThis, _Octree::mRootNode);
	int iTotal = mRootNode.Find(vecPosProbe, fRadius, hFound);

	if (!iTotal) {
		return 0;
	}

	if (iMaxResults == -1) {
		iMaxResults = iTotal;
	} else if (iTotal < iMaxResults) {
		iMaxResults = iTotal;
	}

	if (iMaxResults == 1) {
		int iMinIdx = 0;

		if (bSort) {
			float vecPos[3];
			hFound.GetArray(0, vecPos, sizeof(vecPos));

			float fMinDist = GetVectorDistance(vecPos, vecPosProbe);

			for (int i=1; i<iTotal; i++) {
				hFound.GetArray(i, vecPos, sizeof(vecPos));

				float fDist = GetVectorDistance(vecPos, vecPosProbe);
				if (fDist < fMinDist) {
					fMinDist = fDist;
					iMinIdx = i;
				}
			}
		}

		if (bIncludePos) {
			OctItem eOctItem;
			hFound.GetArray(iMinIdx, eOctItem);
			hResult.PushArray(eOctItem);
		} else {
			hResult.Push(hFound.Get(iMinIdx, OctItem::aData));
		}

		return 1;
	}

	if (bSort) {
		ArrayList hData = new ArrayList(sizeof(vecPosProbe));
		hData.PushArray(vecPosProbe);
		SortADTArrayCustom(hFound, SortFunc_Distance, hData);
		delete hData;
	}

	if (bIncludePos) {
		OctItem eOctItem;
		for (int i=0; i<iMaxResults; i++) {
			hFound.GetArray(i, eOctItem);
			hResult.PushArray(eOctItem);
		}
	} else {
		for (int i=0; i<iMaxResults; i++) {
			hResult.Push(hFound.Get(i, OctItem::aData));
		}
	}

	delete hFound;

	return iMaxResults;
}

public int Native_Octree_Instance(Handle hPlugin, int iArgC) {
	float vecCenter[3];
	GetNativeArray(1, vecCenter, sizeof(vecCenter));

	float fHalfWidth = GetNativeCell(2);

	if (hOctrees == null) {
		hOctrees = new ArrayList(sizeof(_Octree));
	}

	int iBufferSize = GetNativeCell(3);

	OctNode mRootNode = OctNode.Instance(NULL_OCTNODE, vecCenter, fHalfWidth, iBufferSize);

	_Octree eOctree;
	eOctree.vecCenter = vecCenter;
	eOctree.fHalfWidth = fHalfWidth;
	eOctree.mRootNode = mRootNode;
	eOctree.iBufferSize = iBufferSize;

	int iOctreesLength = hOctrees.Length;
	for (int i=0; i<iOctreesLength; i++) {
		if (hOctrees.Get(i, _Octree::bGCFlag)) {
			hOctrees.SetArray(i, eOctree);

			return i+1;
		}
	}

	return iOctreeAlloc = hOctrees.PushArray(eOctree) + 1;
}

public int Native_Octree_Destroy(Handle hPlugin, int iArgC) {
	if (hOctrees != null) {
		int iOctreeIdx = GetNativeCellRef(1)-1;
		if (iOctreeIdx < 0) {
			return 0;
		}

		OctNode mRootNode = view_as<OctNode>(hOctrees.Get(iOctreeIdx, _Octree::mRootNode));
		OctNode.Destroy(mRootNode);

		hOctrees.Set(iOctreeIdx, 1, _Octree::bGCFlag);

		SetNativeCellRef(1, NULL_OCTREE);

		if (iOctreeIdx+1 == iOctreeAlloc) {
			for (int i=iOctreeIdx; i>0; i--) {
				if (!hOctrees.Get(i-1, _Octree::bGCFlag)) {
					hOctrees.Resize(iOctreeAlloc = i);
					return 0;
				}
			}

			hOctrees.Clear();
			iOctreeAlloc = 0;
		}
	}

	return 0;
}

// Callbacks

int SortFunc_Distance(int iIdx1, int iIdx2, Handle hArray, Handle hHndl) {
	ArrayList hList = view_as<ArrayList>(hArray);
	ArrayList hData = view_as<ArrayList>(hHndl);

	float vecPosProbe[3], vecPos1[3], vecPos2[3];
	hData.GetArray(0, vecPosProbe);
	hList.GetArray(iIdx1, vecPos1, sizeof(vecPos1));
	hList.GetArray(iIdx2, vecPos2, sizeof(vecPos2));

	return GetVectorDistance(vecPosProbe, vecPos1) < GetVectorDistance(vecPosProbe, vecPos2) ? -1 : 1;
}
