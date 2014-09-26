%Attempts to schedule the bus.
%returns 
%  bus = scheduled bus if possible
%  sched = true if bus is schedulable,
%false otherwise.
function bus = attemptSchedule(scheduler)
    fprintf('\nAttempting Schedule Optimization\n');
    
    scheduler = preSort(scheduler);

    maxPriority = length(scheduler.Unassigned)-1;
    for i = 0:maxPriority
        fprintf('\n\nScheduling Slot %d\n',i);
        found =false;
        for msg = scheduler.Unassigned  
            fprintf('\tTrying Message %s\n',msg.Desc);
            msgtmp = isSchedulable(scheduler,msg)
            if(msgtmp.Rm<=msgtmp.Dm)

                %scheduler.Unassigned = setdiff(scheduler.Unassigned,msg,'stable');
                for i = 1:length(scheduler.Unassigned)
                  if(isequal(scheduler.Unassigned(i),msg))
                    scheduler.Unassigned(i)=[];
                    break;
                  end
                end
                
                msgtmp.m=i;
                scheduler.Assigned = [scheduler.Assigned,msgtmp];

                found=true;
                fprintf('\tSuccesful\n\n');
                break;
            else
                fprintf('\tUnsuccessful\n\n');
            end
            
        end
        
        if ~found;
            fprintf('Unschedulable Bus\n');
            scheduler.State = SchedStatus.Unschedulable;
            bus=scheduler;
            return;
        end
    end
    
    scheduler.State=SchedStatus.Schedulable;
    bus=scheduler;
end


%sorts the messages in D-J order
function ret = preSort(scheduler)
    [~,idx]=sort([scheduler.Unassigned.Dm]-[scheduler.Unassigned.Jm]);
    scheduler.Unassigned=scheduler.Unassigned(idx);
    
    fprintf('Presort:\n');
    fprintf('Desc\tID\tSm\tTm\tJm\tCm\tDm\n');
    for m=scheduler.Unassigned
        fprintf('%s\t%d\t%d\t%.3f\t%.3f\t%.3f\t%.3f\n', ...
            m.Desc,m.IDm,m.Sm,m.Tm,m.Jm,m.Cm,m.Dm);
    end
    ret = scheduler;
end

% Checks if a message is schedulable given current conditions
% If it is the message is given the given priority.
% returns true if message is schedulable
function ret = isSchedulable(scheduler,msg)
    ret = calcRm(scheduler,msg);
end


% Calculates the total response time of the message given current 
% conditions, if the message is schedulable, set the Rm, else do 
% nothing. Returns true if msg is schedulable, false otherwise.
function ret = calcRm(scheduler,msg)
    Bm=calcBm(scheduler,msg);
    
    tm=calctm(scheduler,msg,Bm);
    if tm < 0
        ret=false;
        return
    end
    
    Qm = calcQm(scheduler,msg,tm);
    
    Wmq = calcWmq(scheduler,msg,Bm,Qm);
    Rmq = msg.Jm+msg.Cm + Wmq-(0:Qm-1)*msg.Tm;
    fprintf('\tCalculating Rm:\n');
    fprintf('\t\tRm(q): ');
    for mm = Rmq
        fprintf('%.3f, ',mm);
    end;
    fprintf('\n');
    
    Rm=max(Rmq);
    fprintf('\t\tRm: %.3f\n',Rm);
    
    msg.Rm=Rm;
    
    ret = msg;
    
end


%Calculates the blocking delay from messages with lower priority
function ret = calcBm(scheduler,msg)
    Bm=0;
    
    cm = msg.Cm
    otherCms = [scheduler.Unassigned.Cm];
    otherCms(find(otherCms==msg.Cm,1))=[];

    if ~isempty(otherCms)
        Bm = max([otherCms]);
    end
    fprintf('\tCalculating Bm: %f\n',Bm);
    ret=Bm;
end

%Calculates the busy period (tm) for messages with this or higher
%priority. The busy period is the max period for which a message of
%priority <m cannot be serviced ???
%returns -1 on overutilized bus;
function ret = calctm(scheduler,msg,Bm)
    fprintf('\tCalculating tm:\n');
    hp = [scheduler.Assigned,msg]; %higher priority
    
    Um=sum( [hp.Cm] ./ [hp.Tm] ); %utilization of >m priority msgs
    fprintf('\t\tUtilization_m: %f\n',Um);
    if Um>1
        fprintf('\t\tOver-utilization of Bus Detected\n');
        ret=-1;
        return
    end
    
    fprintf('\t\ttm: ');
    tm=msg.Cm;
    %if utilization is <=100% then gauranteed to converge
    while true
        fprintf('%.3f, ',tm);
        tm_next=Bm;
        if ~isempty(hp)
            tm_next=errDelay(scheduler,msg,tm)+Bm+sum(ceil((tm+[hp.Jm])./[hp.Tm]).*[hp.Cm]);
        end
        
        if(tm_next==tm)
            fprintf('Converged\n');
            ret=tm;
            return;
        end
        tm=tm_next;
    end
end

%Calculates the maximum number of times msg may be entered into
%queue during busy period
function ret = calcQm(~,msg,tm)
    ret = ceil( (tm+msg.Jm)/msg.Tm );
    fprintf('\tCalculating Qm: %d\n',ret);
end


%Calculates the Queueing delay (Wm) of the message with the 
function ret = calcWmq(scheduler,msg,Bm,Q)
    
    fprintf('\tCalculating Wm:\n')
    Wm      = zeros(1,Q);
    Wm_next = zeros(1,Q);
    Wm(1) = Bm;
    hp    = scheduler.Assigned;
    
    %For each instance in the busy period
    for q = 1:Q
        fprintf('\t\tWm(%d): ',q);
        %iterate until this instance has converged
        while true
            fprintf('%.3f, ', Wm(q));
            Wm_next(q) = Bm+(q-1)*msg.Cm;
            if ~isempty(hp)
               Wm_next(q)=  errDelay(scheduler,msg,Wm(q)+msg.Cm)+Wm_next(q)+...
                   sum(ceil((Wm(q)+[hp.Jm]+scheduler.Tbit)./[hp.Tm]).*[hp.Cm]);
            end
            
            %if over limit unschedulable, stop
            if msg.Jm+Wm(q)-(q-1)*msg.Tm+msg.Cm > msg.Dm
                
                %Wm(q)= Wm_next(q)
                fprintf('Over Dm\n');
                ret=Wm;
                return
            end
            
            %else if converged
            if Wm_next(q)==Wm(q)
                fprintf('Converged\n');
                break; % into next instance of q
            end
            Wm(q)=Wm_next(q);
        end
        
        %set up for next instance of q.
        if q<Q
            Wm(q+1) = Wm(q)+msg.Cm;
        end
    end
    
    ret=Wm;
end

%Gives the Maximum Delay an Error Can cause on the bus in a certain
%time frame.
function ret = errDelay(scheduler,msg,t)
    
    hpUm = [scheduler.Assigned,msg];%higher priority
    ret = (31*scheduler.Tbit+max([hpUm.Cm]))*maxErr(scheduler,t);
end

%Maximum number of Errors which can occur in a certain time frame.
function ret = maxErr(scheduler,t)
    
    ret = ceil((t/scheduler.Tbit)*scheduler.errRate);
end