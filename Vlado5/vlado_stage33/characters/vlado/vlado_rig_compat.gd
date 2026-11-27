extends RefCounted

static func weapon_socket_index(skeleton: Skeleton3D) -> int:
	var index := skeleton.find_bone("WeaponSocket")
	return index if index >= 0 else skeleton.find_bone("WeaponMount")

static func right_hand_index(skeleton: Skeleton3D) -> int:
	var index := skeleton.find_bone("Hand.R")
	return index if index >= 0 else skeleton.find_bone("RightHand")
