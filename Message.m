
classdef Message < handle
    %Represents a CAN message
    %   Holds onto the data related to this message
    
    properties
        %Set at initialization
        Desc = ''      % Description
        IDm  = 0       % ID Size  (Bits)  ID length in the
        Sm   = 0       % Size     (bytes) Number of Bytes in the data portion
        Tm   = 0       % Period   (ms)    The Minimum period at which the message is sent out.
        Jm   = 0       % Jitter   (ms)    The max amount of time between trigger and Queued
        Dm   = 0       % Deadline (ms)    The max allowed time on bus
        
        
        g    = 0      % IDScaler
        Cm   = 0      % Max Tx Time   

        m    = 0      %Priority of this message
        Rm   = 0      %Response Time of message
    end
    

    methods
        %%Message Constructor
        function obj = Message(IDm,Sm,Tm,Jm,Dm,Desc)
            assert( IDm == 11 || IDm== 29 ,'ID Size must be 11 or 29');
            assert( Sm  <= 8 && Sm >= 0  , 'Sm must be in range 0-8');
            
            obj.IDm = IDm;
            obj.Sm=Sm;
            obj.Tm=Tm;
            obj.Jm=Jm;
            obj.Dm=Dm;
            obj.Desc=Desc;
            
            G = 34; %if IDm==11
            if(IDm == 29)
                G=54;
            end
            obj.g=G;
        end
        
        %Calculates the Tx time given tBit in ms
        function setTbit(obj,Tbit)
            obj.Cm = (obj.g+8*obj.Sm+13+floor( (obj.g+8*obj.Sm-1)/4) )*Tbit;
        end
    end 
end

