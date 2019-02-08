classdef myRevDelay < audioPlugin
    
    
    properties
        
        delayL = 0.5;
        delayR = 0.5;
        overtoneL = 0; %initialize to Hann
        overtoneR = 0;
        mixL = 0.5;
        mixR = 0.5;
        feedbackL = 0; %<---
        feedbackR = 0; %<---
        inputLevelL = 1; %<---
        inputLevelR = 1; %<---
    end
    
    properties (Constant)
        hop = 0.5;
        PluginInterface = audioPluginInterface(...
            'InputChannels', 2,... 
            'OutputChannels', 2,...
            audioPluginParameter('inputLevelL', 'DisplayName', 'Left Level',... %<---
            'Label', '', 'Mapping', {'lin', 0 1}),...
            audioPluginParameter('inputLevelR', 'DisplayName', 'Right Level',...
            'Label', '', 'Mapping', {'lin', 0 1}),...
            audioPluginParameter('delayL', 'DisplayName', 'Left Grain Size',...
            'Label', 's', 'Mapping', {'lin', 0.001 1}),...
            audioPluginParameter('delayR', 'DisplayName', 'Right Grain Size',...
            'Label', 's', 'Mapping', {'lin', 0.001 1}),...
            audioPluginParameter('overtoneL', 'DisplayName', 'Left Overtone',...
            'Label', '', 'Mapping', {'lin', 0 1}),...
            audioPluginParameter('overtoneR', 'DisplayName', 'Right Overtone',...
            'Label', '', 'Mapping', {'lin', 0 1}),...
            audioPluginParameter('mixL', 'DisplayName', 'Left Mix',...
            'Label', '', 'Mapping', {'lin', 0 1}),...
            audioPluginParameter('mixR', 'DisplayName', 'Right Mix',...
            'Label', '', 'Mapping', {'lin', 0 1}),...
            audioPluginParameter('feedbackL', 'DisplayName', 'Left Feedback',...
            'Label', '', 'Mapping', {'lin', 0 1}),...
            audioPluginParameter('feedbackR', 'DisplayName', 'Right Feedback',...
            'Label', '', 'Mapping', {'lin', 0 1})...
            );
    end

    properties (Access = private)        
        
        %pSR Sample rate
        pSR
        %window buffers
        xW1 %first windows of left and right channel
        xW2
        xD
        flag
        cnt % [cnt1 cnt2 cntK for L; cnt1 cnt2 cntK for R]
        write % [readL readR]
        order % [orderL orderR]
        
    end
    
    methods
        % Constructor initializes private properties
        function obj = myRevDelay()
            fs = getSampleRate(obj);
            obj.pSR = fs;
            obj.xW1 = zeros(fs, 2);
            obj.xW2 = zeros(fs, 2);
            obj.xD = zeros(2,5*fs, 2);
            obj.flag = [1 1];
            obj.cnt = zeros(3, 2);
            obj.write = [fs fs];
            obj.order = zeros(2, 1);
            
        end
        
        function reset(obj)
            % Reset all properties
            fs = getSampleRate(obj);
            obj.pSR = fs;
            obj.xW1 = zeros(fs, 2);
            obj.xW2 = zeros(fs, 2);
            obj.xD = zeros(2.5*fs, 2);
            obj.flag = [1 1];
            obj.cnt = zeros(3, 2);
            obj.write = [fs fs];
            obj.order = zeros(2, 1);
        end
        
        
        function out = process(obj, in)
            out = in;
            fs = obj.pSR;
            
            ML = floor(obj.delayL*fs);
            MR = round(obj.delayR*fs);
            hL = round(obj.hop * ML);
            hR = round(obj.hop * MR);
            %}
            gL = obj.mixL;
            fbL = obj.feedbackL;
            gR = obj.mixR;
            fbR = obj.feedbackR;
            vL = obj.overtoneL;
            vR = obj.overtoneR;
            volL = obj.inputLevelL;
            volR = obj.inputLevelR;
            
            %define window shape for left
            %wRectL = rectwin(ML);
            wRectL = ones(ML, 1);
            wHannL = hann(ML,'periodic');
            wHannL = flipud(wHannL);
            wL = vL.*wRectL + (1-vL).*wHannL;
            %define window shape for right
            %wRectR = rectwin(obj.MR);
            wRectR = ones(MR, 1);
            wHannR = hann(MR,'periodic');
            wHannR = flipud(wHannR);
            wR = vR.*wRectR + (1-vR).*wHannR;
            out(:,1) = sttr(obj, volL*in(:,1), ML, hL, fs, gL, fbL, wL, 1); %<---
            out(:,2) = sttr(obj, volR*in(:,2), MR, hR, fs, gR, fbR, wR, 2); %<---
        end
        %function for sttr
        function y = sttr(obj, x, M, h, fs, g, fb, w, i)
            temp1 = zeros(fs,1);
            temp2 = zeros(fs,2);
            ind1 = 0; ind2 = 0;
            iniK = obj.flag(i);
            cnt1 = obj.cnt(1, i); %... window 1
            cnt2 = obj.cnt(2, i); %... window 2
            cntK = obj.cnt(3, i); %... at the beginning
            f = length(x); % size of the audio frame
            if f < M
                flipK = [0 0];
                cnt1 = cnt1 + f;
                cnt2 = cnt2 + f;
                if iniK ~= -2 %increase cntK while 
                    cntK = cntK + f;
                end
                if cnt1 < M
                    if cnt1-f+1 <= 0    %<---
                        obj.xW1(M-f+1:M,i) = obj.xW1(M-f+1:M,i) + x; %<---
                    else %<---
                        obj.xW1(cnt1-f+1:cnt1,i) = obj.xW1(cnt1-f+1:cnt1,i) + x; %just add to window
                    end
                else
                    %manage overflow
                    diff1 = f - mod(cnt1, M);
                    obj.xW1(cnt1-f+1:M,i) = obj.xW1(cnt1-f+1:M,i) + x(1:diff1); %<---
                    % store entire window
                    temp1 = obj.xW1(:,i);
                    % store write index
                    ind1 = obj.write(i);
                    if iniK <= 0
                        %if we passed the first hop, change flag to state
                        %-1
                        if iniK == 0
                            iniK = -1;
                        end
                        obj.write(i) = obj.write(i) + h;
                    end
                    %obj.xW1(:,i) = zeros(fs,1);
                    obj.xW1(:,i) = fb * obj.xW1(:,i); %<---
                    if diff1 <= 0
                        diff1 = mod(cnt1, M) - f;
                    end
                    obj.xW1(1:(f - diff1),i) = obj.xW1(1:(f - diff1),i) + x(diff1+1:end); %<---
                    cnt1 = f - diff1;
                    flipK(1) = 1;

                end
                if cnt2 >= h && iniK == 1
                    diffK = f - mod(cnt2,h);
                    iniK = 0;
                    if diffK <= 0
                        diffK = mod(cnt2,h) - f;
                    end
                    obj.xW2(1:(f - diffK),i) = obj.xW2(1:(f - diffK),i) + x(diffK+1:end); %<---
                    cnt2 = f - diffK;
                elseif cnt2 < M && iniK ~= 1
                    if cnt2-f+1 <= 0 %<---
                        obj.xW2(M-f+1:M, i) = obj.xW2(M-f+1:M, i) + x; %<---
                    else 
                        obj.xW2(cnt2-f+1:cnt2,i) = obj.xW2(cnt2-f+1:cnt2,i) + x; %<---
                    end
                elseif cnt2 >= M && iniK ~= 1

                    diff2 = f - mod(cnt2,M);
                    obj.xW2(cnt2-f+1:M,i) = obj.xW2(cnt2-f+1:M,i) + x(1:diff2); %<---
                    temp2 = obj.xW2(:,i);
                    ind2 = obj.write(i);
                    obj.write(i) = obj.write(i) + h;
                    %obj.xW2(:,i) = zeros(fs,1);
                    obj.xW2(:,i) = fb * obj.xW2(:,i); %<---
                    if diff2 <= 0
                        diff2 = mod(cnt2,M) - f;
                    end
                    obj.xW2(1:(f - diff2),i) = x(diff2+1:end); %<---
                    cnt2 = f - diff2;
                    flipK(2) = 1;

                end
 
                if sum(flipK) >= 1
                    obj.order(i) = obj.order(i)+1;
                    obj.order(i) = mod(obj.order(i),2);
                    if sum(flipK) == 2
                        first = min(ind1, ind2);
                        second = max(ind1, ind2);
                        if obj.order(i) == 0
                            obj.xD(first+1:first+M,i) = obj.xD(first+1:first+M,i) + flipud(temp2(1:M)).*w;
                            obj.xD(second+1:second+M,i) = obj.xD(second+1:second+M,i) + flipud(temp1(1:M)).*w;
                            obj.order(i) = obj.order(i)+1;
                            obj.order(i) = mod(obj.order(i),2);
                        else
                            obj.xD(first+1:first+M,i) = obj.xD(first+1:first+M,i) + flipud(temp1(1:M)).*w;

                            obj.xD(second+1:second+M,i) = obj.xD(second+1:second+M,i) + flipud(temp2(1:M)).*w;
                            obj.order(i) = obj.order(i)+1;
                            obj.order(i) = mod(obj.order(i),2);
                        end
                    elseif flipK(1) == 1

                        obj.xD(ind1+1:ind1+M,i) = obj.xD(ind1+1:ind1+M,i) + flipud(temp1(1:M)).*w;

                    elseif flipK(2) == 1
                        obj.xD(ind2+1:ind2+M,i) = obj.xD(ind2+1:ind2+M,i) + flipud(temp2(1:M)).*w;

                    end
                end
                if cntK < M && iniK >= 0
                    y = (1-g)*x;
                elseif cntK >= M && iniK == -1 && sum(flipK) >= 1
                    diffK = f - (cntK - M);
                    y = (1-g)*x + g*[obj.xD(fs-diffK+1:fs,i); obj.xD(fs+1:fs+f-diffK,i)]; %<---
                    iniK = -2;
                    cntK = f - diffK;
                    obj.xD(:,i) = circshift(obj.xD(:,i), -cntK);
                    obj.xD(end-cntK+1:end,i) = zeros(cntK, 1);
                    obj.write(i) = obj.write(i) - cntK;
                else
                    y = (1-g)*x + g*obj.xD(fs+1:fs+f,i); %<---
                    obj.xD(:,i) = circshift(obj.xD(:,i), -f);
                    obj.xD(end-f+1:end,i) = zeros(f, 1);
                    if iniK <= -1
                        obj.write(i) = obj.write(i) - f;
                    else
                        obj.write(i) = fs;
                    end

                end  
            else
                xd = zeros(length(x)+M,1);
                y = zeros(length(x), 1);
                for j=1:h:length(x)-M
                    xW = x(j+M-1:-1:j).*w;
                    xd(j+M:j+2*M-1) = xW+xd(j+M:j+2*M-1);
                    y(j:j+h-1) = (1-g)*x(j:j+h-1)+g*xd(j:j+h-1);    
                end
            end
            obj.cnt(:,i) = [cnt1 cnt2 cntK];
            obj.flag(i) = iniK;
        end
    end
   

end

