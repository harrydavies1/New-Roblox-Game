--!strict
-- Pure ordered-checkpoint state machine; proximity is checked by ObbyService.
local ObbyRun = {}
function ObbyRun.new(route: any, now: number): any
	return { Route = route, StartedAt = now, LastAt = now, Stage = 0, Checkpoint = 0, Finished = false }
end
function ObbyRun.advance(run: any, stage: any, now: number): (boolean, string)
	if run.Finished then return false, "finished" end
	if now - run.StartedAt > 900 then return false, "expired" end
	if type(stage) ~= "number" or stage % 1 ~= 0 or stage ~= run.Stage + 1 or stage > run.Route.Count then return false, "out_of_order" end
	if now - run.LastAt < 0.12 then return false, "too_fast" end
	if stage == run.Route.Count and now - run.StartedAt < run.Route.MinDuration then return false, "too_fast" end
	run.Stage = stage; run.LastAt = now
	if stage % run.Route.CheckpointEvery == 0 and stage < run.Route.Count then run.Checkpoint = stage end
	if stage == run.Route.Count then run.Finished = true; return true, "complete" end
	return true, if stage == run.Checkpoint then "checkpoint" else "step"
end
function ObbyRun.reset(run: any, now: number)
	run.Stage = run.Checkpoint; run.LastAt = now
end
return ObbyRun
