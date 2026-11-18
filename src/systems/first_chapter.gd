extends RefCounted

const LICENSED := 3
const FINISHED := 4


static func mission(step: int) -> Dictionary:
	var briefs := [
		"Increase throttle to 20% to leave the Asteria training lane.",
		"Bank toward the gold diamond and cross the Asteria training gate.",
		"Slow below 28 m/s, deploy gear and dock at Asteria Station.",
		"Fly within 32 m of Caligo Overlook to chart the survey route."
	]
	if step < 0 or step >= briefs.size():
		return {}
	return {"type": "QUALIFICATION" if step < LICENSED else "OVERLOOK",
		"title": "Asteria flight qualification" if step < LICENSED else "Chart Caligo Overlook",
		"description": briefs[step], "progress": step if step < LICENSED else 0,
		"target": 3 if step < LICENSED else 1, "reward": 800 if step < LICENSED else 1100}


static func milestones(step: int, waived: bool) -> String:
	return "CHAPTER 01   /   THE CALIGO ROUTE\n%s  Asteria qualification   →   %s  Survey licence   →   %s  Reach Caligo Overlook" % [
		("Waived" if waived else "Done") if step >= LICENSED else "Active",
		"Earned" if step >= LICENSED else "Locked",
		"Done" if step >= FINISHED else ("Available" if step >= LICENSED else "Upcoming")]
