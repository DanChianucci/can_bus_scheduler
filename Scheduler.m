
classdef Scheduler < handle    
    properties
        %            Benign      Normal     Aggressive
        %Bits Tx     2.02E11     1.98E11    9.79E10
        %Bit Er      6           609        25239
        %Last Bit    0           0          8
        %Error Rate  3.0E-11      3.1E-9       2.6E-7
        errRate    = 2.6E-7;
        Tbit       = 0;
        Assigned   = [];
        Unassigned = [];
        State      = SchedStatus.UnknownStatus;   %Unknown, Schedulable, Unschedulable
    end
    
    
    %Public Methods
    methods
        %Constructs a Scheduler Object with the given bus frequency
        function obj = Scheduler(busFreq,errRate)
            obj.Tbit = 1.0/busFreq;
            obj.errRate = errRate;
            obj.Assigned=[];
            obj.Unassigned = [];
            obj.State = SchedStatus.UnknownStatus;
            fprintf('Initialising Bus With Freq %d, TBit %f, Err Rate: %f\n\n',busFreq,obj.Tbit,errRate);
        end
        
        %Resets the Entire Objct.
        function reset(obj)
            obj.Assigned=[];
            obj.Unassigned=[];
            obj.State = SchedStatus.UnknownStatus;
        end
        
        %Add a single message or a set of messages to the scheduler
        function addMessages(obj,messages)
            fprintf('Adding Messages:\n');
            
            obj.Unassigned = [obj.Unassigned,obj.Assigned];
            obj.Unassigned = [obj.Unassigned,messages];
            obj.Assigned   = [];
            for m=obj.Unassigned
                m.setTbit(obj.Tbit);
            end
            
            fprintf('Desc\tID\tSm\tTm\tJm\tCm\tDm\n');
            for m=obj.Unassigned
                fprintf('%s\t%d\t%d\t%.3f\t%.3f\t%.3f\t%.3f\n', ...
                    m.Desc,m.IDm,m.Sm,m.Tm,m.Jm,m.Cm,m.Dm);
            end
            obj.State = SchedStatus.UnknownStatus;
        end
        
        %Attempts to schedule the bus.
        %returns true if bus is schedulable,
        %false otherwise.
        function ret = attemptSchedule(obj)
            fprintf('\nAttempting Schedule Optimization\n');
            
            obj.preSort();

            maxPriority = length(obj.Unassigned)-1;
            for i = 0:maxPriority
                fprintf('\n\nScheduling Slot %d\n',i);
                found =false;
                for msg = obj.Unassigned  
                    fprintf('\tTrying Message %s\n',msg.Desc);
                    if(obj.isSchedulable(msg))
                        msg.m=i;
                        obj.Assigned = [obj.Assigned,msg];
                        obj.Unassigned = setdiff(obj.Unassigned,msg,'stable');
                        found=true;
                        fprintf('\tSuccesful\n\n');
                        break;
                    else
                        fprintf('\tUnsuccessful\n\n');
                    end
                    
                end
                
                if ~found;
                    fprintf('Unschedulable Bus\n');
                    obj.State = SchedStatus.Unschedulable;
                    ret=false;
                    return;
                end
            end
            obj.State=SchedStatus.Schedulable;
            ret=true;
        end
        
        %Analyzes the Bus in its current Condition
        function ret = analyzeSchedule(obj)
            
            for m = obj.Unassigned
                fprintf('Trying Message %s\n',m.Desc);
                if(obj.calcRm(m))
                    m.m = length(obj.Assigned);
                    obj.Assigned = [obj.Assigned,m];
                    obj.Unassigned = setdiff(obj.Unassigned,m,'stable');
                    fprintf('\tSuccess\n');
                else
                    ret=false;
                    disp('Schedule not Possible');
                    return
                end
            end
            ret =true;
        end
        
    end
    
    
    %Private Methods
    methods(Access=private)
        
        %sorts the messages in D-J order
        function preSort(obj)
            [~,idx]=sort([obj.Unassigned.Dm]-[obj.Unassigned.Jm]);
            obj.Unassigned=obj.Unassigned(idx);
            
            fprintf('Presort:\n');
            fprintf('Desc\tID\tSm\tTm\tJm\tCm\tDm\n');
            for m=obj.Unassigned
                fprintf('%s\t%d\t%d\t%.3f\t%.3f\t%.3f\t%.3f\n', ...
                    m.Desc,m.IDm,m.Sm,m.Tm,m.Jm,m.Cm,m.Dm);
            end
        end
        
        % Checks if a message is schedulable given current conditions
        % If it is the message is given the given priority.
        % returns true if message is schedulable
        function ret = isSchedulable(obj,msg)
            ret = obj.calcRm(msg);
        end
        
        % Calculates the total response time of the message given current 
        % conditions, if the message is schedulable, set the Rm, else do 
        % nothing. Returns true if msg is schedulable, false otherwise.
        function ret = calcRm(obj,msg)
            Bm=obj.calcBm(msg);
            
            tm=obj.calctm(msg,Bm);
            if tm < 0
                ret=false;
                return
            end
            
            Qm = obj.calcQm(msg,tm);
            
            Wmq = obj.calcWmq(msg,Bm,Qm);
            Rmq = msg.Jm+msg.Cm + Wmq-(0:Qm-1)*msg.Tm;
            fprintf('\tCalculating Rm:\n');
            fprintf('\t\tRm(q): ');
            for mm = Rmq
                fprintf('%.3f, ',mm);
            end;
            fprintf('\n');
            
            Rm=max(Rmq);
            fprintf('\t\tRm: %.3f\n',Rm);
            
            if(Rm<=msg.Dm)
                msg.Rm=Rm;
                ret=true;
            else
                ret=false;
            end
        end
        
        
        %Calculates the blocking delay from messages with lower priority
        function ret = calcBm(obj,msg)
            Bm=0;
            lp = setdiff(obj.Unassigned,msg);
            if ~isempty(lp)
                Bm = max([lp.Cm]);
            end
            fprintf('\tCalculating Bm: %f\n',Bm);
            ret=Bm;
        end
        
        %Calculates the busy period (tm) for messages with this or higher
        %priority. The busy period is the max period for which a message of
        %priority <m cannot be serviced ???
        %returns -1 on overutilized bus;
        function ret = calctm(obj,msg,Bm)
            fprintf('\tCalculating tm:\n');
            hp = union(obj.Assigned,msg); %higher priority
            
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
                    tm_next=obj.errDelay(msg,tm)+Bm+sum(ceil((tm+[hp.Jm])./[hp.Tm]).*[hp.Cm]);
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
        function ret = calcWmq(obj,msg,Bm,Q)
            
            fprintf('\tCalculating Wm:\n')
            Wm      = zeros(1,Q);
            Wm_next = zeros(1,Q);
            Wm(1) = Bm;
            hp    = obj.Assigned;
            
            %For each instance in the busy period
            for q = 1:Q
                fprintf('\t\tWm(%d): ',q);
                %iterate until this instance has converged
                while true
                    fprintf('%.3f, ', Wm(q));
                    Wm_next(q) = Bm+(q-1)*msg.Cm;
                    if ~isempty(hp)
                       Wm_next(q)=  obj.errDelay(msg,Wm(q)+msg.Cm)+Wm_next(q)+...
                           sum(ceil((Wm(q)+[hp.Jm]+obj.Tbit)./[hp.Tm]).*[hp.Cm]);
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
        function ret = errDelay(obj,msg,t)
            hpUm = union(obj.Assigned,msg);
            ret = (31*obj.Tbit+max([hpUm.Cm]))*obj.maxErr(t);
        end
        
        %Maximum number of Errors which can occur in a certain time frame.
        function ret = maxErr(obj,t)
            
            ret = ceil((t/obj.Tbit)*obj.errRate);
        end
        
    end
end


