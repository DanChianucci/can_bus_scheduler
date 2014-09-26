%Add a single message or a set of messages to the scheduler
function ret = addMessages(scheduler,messages)
    fprintf('Adding Messages:\n');
    
    scheduler.Unassigned = [scheduler.Unassigned,scheduler.Assigned];
    scheduler.Unassigned = [scheduler.Unassigned,messages];
    scheduler.Assigned   = [];
    
    for i=1:length(scheduler.Unassigned)
        m=scheduler.Unassigned(i);
        m=setTbit(m,scheduler.Tbit);
        scheduler.Unassigned(i)=m;
    end
    
    fprintf('Desc\tID\tSm\tTm\tJm\tCm\tDm\n');
    for m=scheduler.Unassigned
        fprintf('%s\t%d\t%d\t%.3f\t%.3f\t%.3f\t%.3f\n', ...
            m.Desc,m.IDm,m.Sm,m.Tm,m.Jm,m.Cm,m.Dm);
    end
    scheduler.State = SchedStatus.UnknownStatus;
    ret = scheduler;
end

%Calculates the Tx time given tBit in ms
function ret = setTbit(obj,Tbit)
    obj.Cm = (obj.g+8*obj.Sm+13+floor( (obj.g+8*obj.Sm-1)/4) )*Tbit;
    ret = obj;
end