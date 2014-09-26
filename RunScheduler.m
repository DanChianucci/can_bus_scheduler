bus = Scheduler(busFreq,errRate);
bus = addMessages(bus,messageSet);
bus = attemptSchedule(bus);
isSchedulable = bus.State == SchedStatus.Schedulable;

if isSchedulable 
    disp('Bus is Schedulable');
    util = sum( [bus.Assigned.Cm]./[bus.Assigned.Tm] );
    solution = bus.Assigned;
    fprintf('Total Util: %.3f \n',util*100);
    fprintf('Solution:\n');
    
    mat= {'Description','Deadline','Response','Percent','Max Freq','Min Freq'};
    for i= 1:length(solution)
        msg = solution(i);
        mat=[mat; {msg.Desc  , msg.Dm , msg.Rm , (msg.Rm/msg.Dm)*100,1/(msg.Tm)*1000 ,1/(msg.Tm+msg.Rm)*1000 }];
        clear msg;
    end;

    disp(mat);
    
else
    disp('Bus is not Schedulable');
    util=0;
    solution=[];
end



