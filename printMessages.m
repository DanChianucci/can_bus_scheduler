function printMessages( messageList )
%PRINTMESSAGES Prints all messages in the given message List

    fprintf('Desc\tID\tSm\tTm\tJm\tCm\tDm\n');
    for m=messageList
        fprintf('%s\t%d\t%d\t%.3f\t%.3f\t%.3f\t%.3f\n', ...
        m.Desc,m.IDm,m.Sm,m.Tm,m.Jm,m.Cm,m.Dm);
    end

end

