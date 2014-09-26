%Resets the Entire schedulerct.
function reset(scheduler)
    scheduler.Assigned=[];
    scheduler.Unassigned=[];
    scheduler.State = SchedStatus.UnknownStatus;
end
