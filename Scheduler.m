%Constructs a Scheduler schedulerect with the given bus frequency
function scheduler = Scheduler( busFreq, errRate )
    scheduler.Tbit = 1.0/busFreq;
    scheduler.errRate = errRate;
    scheduler.Assigned=[];
    scheduler.Unassigned = [];
    scheduler.State = SchedStatus.UnknownStatus;
    fprintf('Initialising Bus With Freq %d, TBit %f, Err Rate: %f\n\n',busFreq,scheduler.Tbit,errRate);
end



        



%Analyzes the Bus in its current Condition
function ret = analyzeSchedule(scheduler)
    for m = scheduler.Unassigned
        fprintf('Trying Message %s\n',m.Desc);
        if(calcRm(scheduler,m))
            m.m = length(scheduler.Assigned);
            scheduler.Assigned = [scheduler.Assigned,m];
            scheduler.Unassigned = setdiff(scheduler.Unassigned,m,'stable');
            fprintf('\tSuccess\n');
        else
            ret=false;
            disp('Schedule not Possible');
            return
        end
    end
    ret =true;
end







