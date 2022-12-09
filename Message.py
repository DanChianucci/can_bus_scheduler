
from enum import Enum, auto

class SchedStatus(Enum):
    UNKNOWN = auto()
    SCHEDULABLE = auto()
    UNSCHEDULABLE = auto()



class Message:

    """
    Representation of a CAN bus message

    Parameters
    -----------------
    Desc  : Description of the message
    IDm   : ID Size  (Bits)  ID length in the
    Sm    : Size     (bytes) Number of Bytes in the data portion
    Tm    : Period   (ms)    The Minimum period at which the message is sent out
    Jm    : Jitter   (ms)    The max amount of time between trigger and Queued
    Dm    : Deadline (ms)    The max allowed time on bus
    g     : IDScaler
    Cm    : Max Tx Time
    m     : Priority of this message
    Rm    : Response Time of message
    """

    def __init__(self, IDm, Sm, Tm, Jm,Dm, desc):
        self.description = desc
        self.IDm = IDm
        self.g = 34 if IDm == 11 else 54

        self.Sm  = Sm
        self.Tm  = Tm
        self.Jm  = Jm
        self.Dm  = Dm

        self.Cm = self.g+8*self.Sm+13+(self.g+8*self.Sm-1)//4 # * bit_time
        self.m = 0
        self.Rm = 0


class Scheduler:
    def __init__(self, bus_freq,err_rate):
        self.Tbit       = 1.0/bus_freq
        self.errRate    = err_rate
        self.assigned   = []
        self.unassigned = []
        self.state      = SchedStatus.UNKNOWN


    def reset(self):
        self.assigned   = []
        self.unassigned = []
        self.state      = SchedStatus.UNKNOWN

    def add_messages(self, messages):
        self.state= SchedStatus.UNKNOWN
        self.unassigned.extend(self.assigned)
        self.assigned = []

        if isinstance(messages,Message):
            self.unassigned.append(messages)
        else:
            self.unassigned.extend(messages)

    def attempt_schedule(self):
        self._do_pre_sort()

        max_priority = len(self.unassigned)-1
        for i in range(max_priority):
            found = False
            for msg in self.unassigned[:]:
                if self.is_schedulable(msg):
                    msg.set_priority(i)
                    self.assigned.append(msg)
                    self.unassigned.remove(msg)
                    found =True
                    break
                else:
                    pass
            if not found:
                self.state = SchedStatus.UNSCHEDULABLE
                return False
        self.state = SchedStatus.SCHEDULABLE

    def analyze_schedule(self):
        for m in self.unassigned[:]:
            if self.calc_rm(m):
                m.set_priority(len(self.assigned))
                self.assigned.append(m)
                self.unassigned.remove(m)
            else:
                return False
        return True

    def _do_pre_sort(self):
        self.unassigned.sort(key = lambda x: x.Dm-x.Jm)

    def _is_schedulable(self, msg):
        return self.calc_rm(msg)


    # Calculates the total response time of the message given current
    # conditions, if the message is schedulable, set the Rm, else do
    # nothing. Returns true if msg is schedulable, false otherwise.
    def calcRm(self, msg):
        Bm=self.calcBm(msg);

        tm=self.calctm(msg,Bm);
        if tm < 0:
            return False


        Qm = self.calcQm(msg,tm);

        Wmq = self.calcWmq(msg,Bm,Qm);
        Rm = -float('inf')
        for i in range(Qm):
            Rm = max(Rm, msg.Jm+msg.Cm + Wmq[i]-i*msg.Tm)

        if(Rm<=msg.Dm):
            msg.Rm=Rm;
            return True
        else:
            return False




    #Calculates the blocking delay from messages with lower priority
    def calcBm(self, msg):
        Bm=0;
        lp = setdiff(self.unassigned,msg);
        if ~isempty(lp)
            Bm = max([lp.Cm]);

        fprintf('\tCalculating Bm: #f\n',Bm);
        ret=Bm;


    #Calculates the busy period (tm) for messages with this or higher
    #priority. The busy period is the max period for which a message of
    #priority <m cannot be serviced ???
    #returns -1 on overutilized bus;
    def calctm(self, msg,Bm):
        fprintf('\tCalculating tm:\n');
        hp = union(self.assigned,msg); #higher priority

        Um=sum( [hp.Cm] ./ [hp.Tm] ); #utilization of >m priority msgs
        fprintf('\t\tUtilization_m: #f\n',Um);
        if Um>1
            fprintf('\t\tOver-utilization of Bus Detected\n');
            ret=-1;
            return


        fprintf('\t\ttm: ');
        tm=msg.Cm;
        #if utilization is <=100# then gauranteed to converge
        while true
            fprintf('#.3f, ',tm);
            tm_next=Bm;
            if ~isempty(hp)
                tm_next=self.errDelay(msg,tm)+Bm+sum(ceil((tm+[hp.Jm])./[hp.Tm]).*[hp.Cm]);


            if(tm_next==tm)
                fprintf('Converged\n');
                ret=tm;
                return;

            tm=tm_next;



    #Calculates the maximum number of times msg may be entered into
    #queue during busy period
    def calcQm(self,msg,tm)
        ret = ceil( (tm+msg.Jm)/msg.Tm );
        fprintf('\tCalculating Qm: #d\n',ret);



    #Calculates the Queueing delay (Wm) of the message with the
    def calcWmq(self, msg,Bm,Q):

        fprintf('\tCalculating Wm:\n')
        Wm      = zeros(1,Q);
        Wm_next = zeros(1,Q);
        Wm(1) = Bm;
        hp    = self.assigned;

        #For each instance in the busy period
        for q = 1:Q
            fprintf('\t\tWm(#d): ',q);
            #iterate until this instance has converged
            while true
                fprintf('#.3f, ', Wm(q));
                Wm_next(q) = Bm+(q-1)*msg.Cm;
                if ~isempty(hp)
                    Wm_next(q)=  self.errDelay(msg,Wm(q)+msg.Cm)+Wm_next(q)+...
                        sum(ceil((Wm(q)+[hp.Jm]+self.Tbit)./[hp.Tm]).*[hp.Cm]);


                #if over limit unschedulable, stop
                if msg.Jm+Wm(q)-(q-1)*msg.Tm+msg.Cm > msg.Dm

                    #Wm(q)= Wm_next(q)
                    fprintf('Over Dm\n');
                    ret=Wm;
                    return


                #else if converged
                if Wm_next(q)==Wm(q)
                    fprintf('Converged\n');
                    break; # into next instance of q

                Wm(q)=Wm_next(q);


            #set up for next instance of q.
            if q<Q
                Wm(q+1) = Wm(q)+msg.Cm;



        ret=Wm;


    #Gives the Maximum Delay an Error Can cause on the bus in a certain
    #time frame.
    def errDelay(self, msg,t):
        hpUm = union(self.assigned,msg);
        ret = (31*self.Tbit+max([hpUm.Cm]))*self.maxErr(t);


    #Maximum number of Errors which can occur in a certain time frame.
    def maxErr(self, t):

        ret = ceil((t/self.Tbit)*self.errRate);
