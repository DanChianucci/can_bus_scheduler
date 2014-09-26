
%Represents a CAN message
%   Holds onto the data related to this message
%        Desc      % Description
%        IDm       % ID Size  (Bits)  ID length in the
%        Sm        % Size     (bytes) Number of Bytes in the data portion
%        Tm        % Period   (ms)    The Minimum period at which the message is sent out.
%        Jm        % Jitter   (ms)    The max amount of time between trigger and Queued
%        Dm        % Deadline (ms)    The max allowed time on bus
%        g         % IDScaler
%        Cm        % Max Tx Time   
%        m         % Priority of this message
%        Rm        % Response Time of message
function obj = Message(IDm,Sm,Tm,Jm,Dm,Desc)
    assert( IDm == 11 || IDm== 29 ,'ID Size must be 11 or 29');
    assert( Sm  <= 8 && Sm >= 0  , 'Sm must be in range 0-8');
    
    obj.Desc=Desc;
    obj.IDm = IDm;
    obj.Sm=Sm;
    obj.Tm=Tm;
    obj.Jm=Jm;
    obj.Dm=Dm;
    
    
    if (IDm==11) 
      obj.g = 34; 
    else 
      obj.g=54;
    end;
    obj.Cm = 0;
    
    obj.m=0;
    obj.Rm=0;
end
        
        



