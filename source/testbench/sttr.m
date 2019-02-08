function [y, iniK, cnt, xW1, xW2, xD, write, order] = ...
    sttr(x, M, h, fs, g, w, iniK, cnt, xW1, xW2, xD, write, order)
    %to keep count of the number of samples that are passed through
    cnt1 = cnt(1); %... window 1
    cnt2 = cnt(2); %... window 2
    cntK = cnt(3); %... at the beginning
    f = length(x); % size of the audio frame
    if f < M
        flipK = [0 0];
        cnt1 = cnt1 + f;
        cnt2 = cnt2 + f;
        if iniK ~= -2 %increase cntK while 
            cntK = cntK + f;
        end
        %if window 1 is not yet filler
        if cnt1 < M
            xW1(cnt1-f+1:cnt1) = x; %just add to window
        else
            % window 1 is fully filled
            %manage overflow
            diff1 = f - mod(cnt1, M);
            xW1(cnt1-f+1:M) = x(1:diff1);
            % store entire window
            temp1 = xW1;
            % 
            ind1 = write;
            if iniK <= 0
                if iniK == 0
                    iniK = -1;
                end
                write = write + h;
            end
            xW1 = zeros(fs,1);
            if diff1 <= 0
                diff1 = mod(cnt1, M) - f;
            end
            xW1(1:(f - diff1)) = x(diff1+1:end);
            cnt1 = f - diff1;
            flipK(1) = 1;

        end
        % if at the beginning, it passes the first hop from the input
        % buffer
        if cnt2 >= h && iniK == 1
            diffK = f - mod(cnt2,h);
            iniK = 0; %switched state to skip this branch in the future
            if diffK <= 0
                diffK = mod(cnt2,h) - f;
            end
            xW2(1:(f - diffK)) = x(diffK+1:end);
            cnt2 = f - diffK;
            % if the window 2 is not yet filled
        elseif cnt2 < M && iniK ~= 1
            xW2(cnt2-f+1:cnt2) = x;
        elseif cnt2 >= M && iniK ~= 1
            % window 2 is fully filled manage overflow
            diff2 = f - mod(cnt2,M);
            xW2(cnt2-f+1:M) = x(1:diff2);
            temp2 = xW2;
            ind2 = write;
            write = write + h;
            xW2(xW2 ~= 0) = 0;
            if diff2 <= 0
                diff2 = mod(cnt2,M) - f;
            end
            xW2(1:(f - diff2)) = x(diff2+1:end);
            cnt2 = f - diff2;
            flipK(2) = 1;

        end
        % if at least one of the windows are fully filled
        if sum(flipK) >= 1
            % order parameter to keep track of which of the two windows
            % need to be inserted in xD
            order = order+1;
            order = mod(order,2);
            % if both windows are filled, order of insertion needs to be
            % resolved
            if sum(flipK) == 2
                first = min(ind1, ind2);
                second = max(ind1, ind2);
                if order == 0
                    xD(first+1:first+M) = xD(first+1:first+M) + flipud(temp2(1:M)).*w;
                    xD(second+1:second+M) = xD(second+1:second+M) + flipud(temp1(1:M)).*w;
                    order = order+1;
                    order = mod(order,2);
                else
                    xD(first+1:first+M) = xD(first+1:first+M) + flipud(temp1(1:M)).*w;
                    xD(second+1:second+M) = xD(second+1:second+M) + flipud(temp2(1:M)).*w;
                    order = order+1;
                    order = mod(order,2);
                end
            elseif flipK(1) == 1
                xD(ind1+1:ind1+M) = xD(ind1+1:ind1+M) + flipud(temp1(1:M)).*w;
            elseif flipK(2) == 1
                xD(ind2+1:ind2+M) = xD(ind2+1:ind2+M) + flipud(temp2(1:M)).*w;
            end
        end
        %if we are still at the beginning of the input buffer and window 1
        %is still not filled
        if cntK < M && iniK >= 0
            y = (1-g)*x;
        % if first window is filled, need to resolve the moment when the
        % delayed reversed window is inserted in the output frame
        elseif cntK >= M && iniK == -1 && sum(flipK) >= 1
            diffK = f - (cntK - M);
            y = (1-g)*x + g*[xD(fs-diffK+1:fs); xD(fs+1:fs+f-diffK)];
            iniK = -2;
            cntK = f - diffK;
            %xD acts like a shift register
            xD = circshift(xD, -cntK);
            xD(end-cntK+1:end) = zeros(cntK, 1);
            write = write - cntK;
        % for the rest of the windows, the reading from xD is done at the
        % same position
        else
            y = (1-g)*x + g*xD(fs+1:fs+f);
            xD = circshift(xD, -f);
            xD(end-f+1:end) = zeros(f, 1);
            if iniK <= -1
                write = write - f;
            else
                write = fs;
            end
        end 
    % if f < M
    else
        xd = zeros(length(x)+M,1);
        y = zeros(length(x), 1);
        for i=1:h:length(x)-M
            xW = x(i+M-1:-1:i).*w;
            xd(i+M:i+2*M-1) = xW+xd(i+M:i+2*M-1);
            y(i:i+h-1) = (1-g)*x(i:i+h-1)+g*xd(i:i+h-1);    
        end
    end
    cnt = [cnt1 cnt2 cntK];
end