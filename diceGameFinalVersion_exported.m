classdef diceGameFinalVersion_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure         matlab.ui.Figure
        BGMToggleButton  matlab.ui.control.Button
        howToPlay        matlab.ui.control.Button
        NewGameButton    matlab.ui.control.Button
        Player2LitUp     matlab.ui.control.Label
        Player1LitUp     matlab.ui.control.Label
        playerTwoWins    matlab.ui.control.Image
        playerOneWins    matlab.ui.control.Image
        Player2Label     matlab.ui.control.Label
        Player1Label     matlab.ui.control.Label
        UITable          matlab.ui.control.Table
        Player2Icon      matlab.ui.control.Image
        Player1Icon      matlab.ui.control.Image
        dice3            matlab.ui.control.Image
        dice2            matlab.ui.control.Image
        dice1            matlab.ui.control.Image
        dice4            matlab.ui.control.Image
        dice5            matlab.ui.control.Image
        KeepPileButton   matlab.ui.control.Button
        RollButton       matlab.ui.control.Button
    end

    
    properties (Access = private)
        CurrentDice % Stores the current dice roll
        rollCount = 0 % tracks the number of rolls
        keptDice % logical array keeping track of which dice is kept (true = kept, false = not kept)

        diceFaces = zeros(1,5) % integer array keeping track of the numbers on the faces of the dice for scoring purposes
        playerTurn = 1 % track whose turn it is (Player 1 or Player 2)
        turnScored = 0 % track whether or not turn has been scored
        totalScore = [0,0] % total score for both players
        turnCount = 0 % tracks the number of turns each player has had
        yahtzeeCount = [0,0] % tracks the number of yahtzees for each player

        keptPosition %position of kept dice
        originalPosition % original position of dice
        currentScore % score to be input into the table
        
        %ThingSpeak Properties
        playerNumber = 0 % stores whether or not the person is player 1 or player 2
        firstRollScored = false; % ensures player cannot reselect the player 2 icon and score a roll a second time
        channelID = 2974844 % remote play channelID
        writeKey = 'GI76QEANZKTCBWSC' % remote play API Write Key
        readKey = 'ITDOCE4KSLIFP7A7' % remote play API Read Key
        userKey = 'NV1BIT89KY3FZMLM' % remote play API User Key
        currReadVar % stores the current index from ThingSpeak channel

        localMode = false % true = one device, false = two device
        BGMPlayer % background music player
        BGMData     % original full-volume audio data
        Fs          % sample rate of the audio
        soundMuted = false;

    end
    
    methods (Access = private)
        
        function [] = yahtzeeAudioClip(app) %To be called whenever yahtzee is rolled
                load celebratorySoundClip.mp3
                
                if app.soundMuted
                    % Fade to lower volume
                    stop(app.BGMPlayer);
                    quieterY = app.BGMData * 0.5; % reduce volume to 20%
                    app.BGMPlayer = audioplayer(quieterY, app.Fs);
                    play(app.BGMPlayer);
    
                    [x,Ft] = audioread("celebratorySoundClip.mp3"); 
                    sound(x,Ft) %Plays audio
                    %To call this function, use: yahtzeeAudioClip(app)
        
                    % After short delay, restore full volume
                    pause(1); % or length of sound effect
                    stop(app.BGMPlayer);
                    app.BGMPlayer = audioplayer(app.BGMData, app.Fs); % restore original volume
                    play(app.BGMPlayer);
                else
                    [x,Ft] = audioread("celebratorySoundClip.mp3"); 
                    sound(x,Ft) %Plays audio
                    %To call this function, use: yahtzeeAudioClip(app)
                end
        end

        function [] = remotePlayScoring(app) % to await scoring from the opponent
            loopVar = true;
            pause(5)
            while loopVar == true % checks until opponent has scored their turn
                pause(randi(5));
                app.currReadVar = thingSpeakRead(app.channelID, 'ReadKey', app.readKey, 'Fields', [1,2,3,4], 'OutputFormat', 'Table');
                if size(app.currReadVar) ~= 0 
                        %uialert(app.UIFigure, 'Entered 1','');
                        if app.currReadVar{1,5} ~= app.playerNumber % if not player's turn
                            % collect info from opponent/ThingSpeak channel
                            if app.currReadVar{1,4} > app.yahtzeeCount(app.playerTurn) % play yahtzee sound if opponent got a yahtzee
                                yahtzeeAudioClip(app);
                                app.yahtzeeCount(app.playerTurn) = app.currReadVar{1,4}; % updates yahtzeeCount
                            end
                            app.updateTableScores(app.currReadVar{1,2},app.currReadVar{1,3}); % updates the table with the opponent's score
                            app.RollButton.Enable = 'on'; % allows player to roll their turn
                            
                            if app.playerTurn == 2 % updates playerTurn
                                app.playerTurn = 1;
                                app.Player1LitUp.Visible = 'on';
                                app.Player2LitUp.Visible = 'off'; 
                            else
                                app.playerTurn = app.playerTurn + 1; 
                                app.Player2LitUp.Visible = 'on';
                                app.Player1LitUp.Visible = 'off'; 
                            end

                            loopVar = false; % ends check for opponent's score while player makes their turn
                            
                            url = sprintf('https://api.thingspeak.com/channels/%s/feeds.json?api_key=%s', num2str(app.channelID), app.userKey); % clears channel for ThingSpeak purposes
                            webwrite(url, weboptions('RequestMethod','delete'));

                            %uialert(app.UIFigure, 'Entered 2','');
                        end
                end
            end
        end

        function [] = updateTableScores(app, index, score)
                app.UITable.Data{index,app.playerTurn+1} = score;

                %Subtotal
                sectionScores = zeros(1,13);
                for i = 1:6 % converts top section scores to numbers (0 for empty cells)
                    if app.UITable.Data{i,app.playerTurn+1} ~= ""
                        sectionScores(i) = app.UITable.Data{i,app.playerTurn+1};
                    end
                end
                if sum(sectionScores) >= 63 % calculates bonus for top section
                    app.UITable.Data{7,app.playerTurn+1} = 35;
                end
                app.UITable.Data{8,app.playerTurn+1} = ScoreFunction(sectionScores, "subtotal");
                
                %Yahtzee Bonus
                if app.yahtzeeCount(app.playerTurn) > 0
                    app.UITable.Data{17,app.playerTurn+1} = (app.yahtzeeCount(app.playerTurn) - 1) .* 100;
                end

                %Total
                for j = 10:16 % converts remaining scores to numbers (0 for empty cells)
                    if app.UITable.Data{j,app.playerTurn+1} ~= ""
                        sectionScores(j-3) = app.UITable.Data{j,app.playerTurn+1};
                    end
                end
                app.totalScore(app.playerTurn) = sum(sectionScores) + str2double(app.UITable.Data{7, app.playerTurn+1}) + str2double(app.UITable.Data{17,app.playerTurn+1});
                app.UITable.Data{18,app.playerTurn+1} = app.totalScore(app.playerTurn);

        end
        
        function [] = playerVictoryAnimation(app)
            %Player Victory Animation

            if app.totalScore(1) > app.totalScore(2)
                app.playerOneWins.Visible = 'on'; 
                width = 10;
                height = 10;
                finalWidth = 500;
                finalHeight = 500;
                numFrames = 100;
                
                % Set initial position (centered)
                centerX = app.playerOneWins.Position(1) + app.playerOneWins.Position(3)/2;
                centerY = app.playerOneWins.Position(2) + app.playerOneWins.Position(4)/2;
                
                for i = 1:numFrames
                    scale = i / numFrames;
                    tempWidth = width + (finalWidth - width) * scale;
                    tempHeight = height + (finalHeight - height) * scale;
                
                    % Center the image as it grows
                    x = centerX - tempWidth/2;
                    y = centerY - tempHeight/2;
                
                    app.playerOneWins.Position = [x, y, tempWidth, tempHeight];
                    pause(0.02);
                    drawnow;
                end

            elseif app.totalScore(2) > app.totalScore(1)
                app.playerTwoWins.Visible = 'on'; 
                width = 10;
                height = 10;
                finalWidth = 500;
                finalHeight = 500;
                numFrames = 100;
                
                % Set initial position (centered)
                centerX = app.playerTwoWins.Position(1) + app.playerTwoWins.Position(3)/2;
                centerY = app.playerTwoWins.Position(2) + app.playerTwoWins.Position(4)/2;
                
                for i = 1:numFrames
                    scale = i / numFrames;
                    tempWidth = width + (finalWidth - width) * scale;
                    tempHeight = height + (finalHeight - height) * scale;
                
                    % Center the image as it grows
                    tempX = centerX - tempWidth/2;
                    tempY = centerY - tempHeight/2;
                
                    app.playerTwoWins.Position = [tempX, tempY, tempWidth, tempHeight];
                    pause(0.02);
                    drawnow;
                end
            end
           
            pause(5);
            app.playerTwoWins.Visible = 'off'; 
            app.playerOneWins.Visible = 'off'; 

            app.NewGameButton.Visible = "on"; %allows players to start a new game
            app.NewGameButton.Enable = "on";
         
        end
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            
            
            [y, app.Fs] = audioread('SoftBackgroundLoop.mp3');         % or your file name
            app.BGMData = y;

            % Create the audioplayer
            app.BGMPlayer = audioplayer(app.BGMData, app.Fs);

            % Looping: replay when the audio finishes
            app.BGMPlayer.StopFcn = @(~,~) play(app.BGMPlayer);

            % Start playing
            play(app.BGMPlayer);

            choice = uiconfirm(app.UIFigure,'Are both players playing on this same device? (Recommended)','Game Mode Selection', ...
            'Options', {'Yes', 'No'});

            if strcmp(choice, 'Yes')
                app.localMode = true;
                uialert(app.UIFigure, 'Local mode enabled. Players will share this device.', 'Local Game');
                app.RollButton.Enable = 'on';        % Enable roll right away
                app.playerNumber = 1;                % default to Player 1
            else
                app.localMode = false;
                uialert(app.UIFigure, 'Online mode enabled. Each player must click their icon to start.', 'Online Game');

                url = sprintf('https://api.thingspeak.com/channels/%s/feeds.json?api_key=%s', num2str(app.channelID), app.userKey); % clears channel for ThingSpeak purposes
                webwrite(url, weboptions('RequestMethod','delete'));
            end

            app.NewGameButton.Visible = "off"; % hides the new game button until the end of the previous game
            app.NewGameButton.Enable = "off";
            
            app.playerOneWins.Visible = 'off';
            app.playerTwoWins.Visible = 'off';

            app.Player1LitUp.Visible = 'on';
            app.Player2LitUp.Visible = 'off';


            %Table Setup
            Objectives = ["Ones";"Twos";"Threes";"Fours";"Fives";"Sixes";"Bonus (63+)";"Subtotal";"";"Three of a Kind";"Four of a Kind";"Full House";"Small Straight";"Large Straight";"Yahtzee";"Chance";"Yahtzee Bonus";"Total"];
            Player1 = ["";"";"";"";"";"";0;0;"";"";"";"";"";"";"";"";0;0];
            Player2 = ["";"";"";"";"";"";0;0;"";"";"";"";"";"";"";"";0;0];
            app.UITable.Data = table(Objectives, Player1, Player2);
            %To access/change any element in the table:
            %app.UITable.Data{row,column}
            %Note: All Player1 scores are in column 2 and all Player2 scores are in column 3

            app.keptDice = false(1,5);

            %Game Start
            if ~app.localMode
                uialert(app.UIFigure, 'Select Player 1 or Player 2 by clicking the respective icon. Make sure your opponent selects a different player icon.','Select Player Number');
                uialert(app.UIFigure, 'Remote play is very slow to run. Be prepared to wait about 20 seconds for the opposing scores to update before continuing with your next turn.','Warning')
                app.RollButton.Enable = 'off';
            end
            uialert(app.UIFigure, 'That’s it! Press OK to begin.','');
            uialert(app.UIFigure, 'The Lower-Section combinations are as follows: Three of a Kind (roll three of the same number) (score equals the sum of all five dice), Four of a Kind (roll four of the same number) (score equals the sum of all five dice), Full House (get three of a kind and a pair) (25 pts), Small Straight (four sequential dice) (30 pts), Chance (when none of the above combinations are met) (score is sum of all five dice), Large Straight (five sequential dice) (40 pts), Yahtzee (five of a kind) (50 pts).','How to play Yahtzee (3/3)');
            uialert(app.UIFigure, 'At the end of each turn, you can pick one of 13 combinations for your rolls to fall into. There are many different combinations to accumulate points in Yahtzee. The Upper-Section ones are as follows: Ones (roll as many ones as possible), Twos (roll as many twos), Threes (roll as many threes), Fours (roll as many fours), Fives (roll as many fives), and Sixes (roll as many sixes). For these, the sum of the correct-numbered rolls will be counted to calculate the player’s score. If the player amasses over 63 points, they get a bonus of 35 points added to their score.', 'How to play Yahtzee (2/3)');
            uialert(app.UIFigure, 'You will get three rolls per turn, and 13 turns for a complete game. On each turn, you must roll all five dice during the first roll; however, you can decide which dice to roll on the second and third roll (if you want to keep certain dice values, simply move the dice into the “keep” pile on the bottom right of the screen). The dice that are not in the “keep” pile will be rolled.', 'How to play Yahtzee (1/3)');

             app.dice1.Enable = 'off'; % turns of kept button for dice before the first roll
             app.dice2.Enable = 'off';
             app.dice3.Enable = 'off';
             app.dice4.Enable = 'off';
             app.dice5.Enable = 'off';
           
             if app.localMode
                app.RollButton.Enable = 'on';
             end

        end

        % Button pushed function: RollButton
        function RollButtonPushed(app, event)

            if app.rollCount < 3 
                if isempty(app.keptDice)
                    app.keptDice = false(1,5); % redundancy 
                end

                filenames = ["one.png", "two.png", "three.png", "four.png", "five.png", "six.png"];
               
                for i = 1:5
    
                    if ~app.keptDice(i) % rolls dice not kept
                        rng("shuffle");
                        dice = randi(6); %generates a random number from 1-6
                        app.diceFaces(i) = dice;
                    
                    app.CurrentDice = dice; %stores dice values in a property
                    imgFile = filenames(dice); % appropriate filename
        
                        switch i 
                            case 1 
                                app.dice1.ImageSource = imgFile;
                            case 2
                                app.dice2.ImageSource = imgFile;
                            case 3
                                app.dice3.ImageSource = imgFile;
                            case 4
                                app.dice4.ImageSource = imgFile;
                            case 5
                                app.dice5.ImageSource = imgFile;
                        end
                    end
                end
                 
              
                app.rollCount = app.rollCount + 1; % incremental roll counter
                if app.rollCount < 1
                    app.dice1.Enable = 'off'; % turns off kept button for dice before the first roll
                    app.dice2.Enable = 'off';
                    app.dice3.Enable = 'off';
                    app.dice4.Enable = 'off';
                    app.dice5.Enable = 'off';
                else
                    app.dice1.Enable = 'on'; % turns on kept button for dice after the first roll
                    app.dice2.Enable = 'on';
                    app.dice3.Enable = 'on';
                    app.dice4.Enable = 'on';
                    app.dice5.Enable = 'on';
                end
    
                if app.rollCount >= 3
                    app.RollButton.Enable = 'off'; %disables the roll button                  
                end
            end
            
            [~,frequency] = mode(app.diceFaces,"all"); % counts the largest multiple of the dice
            if frequency == 5 % checks for Yahtzee
                yahtzeeAudioClip(app)

                if app.UITable.Data{15,app.playerTurn+1} ~= "" && str2double(app.UITable.Data{15,app.playerTurn+1}) == 50
                    app.yahtzeeCount(app.playerTurn) = app.yahtzeeCount(app.playerTurn) + 1;
                end
            end

        end

        % Image clicked function: dice1
        function dice1ImageClicked(app, event)
            if app.dice1.Position == [528 121 51 42]
                app.dice1.Position = [280 121 51 42];
            else
                app.dice1.Position = [528 121 51 42];
            end
            app.keptDice(1) = ~app.keptDice(1); % toggle on
        end

        % Image clicked function: dice2
        function dice2ImageClicked(app, event)
            if app.dice2.Position == [578 121 51 42]
                app.dice2.Position = [330 121 51 42];
            else
                app.dice2.Position = [578 121 51 42];
            end
            app.keptDice(2) = ~app.keptDice(2);
        end

        % Image clicked function: dice3
        function dice3ImageClicked(app, event)
            if app.dice3.Position == [528 70 51 42]
                app.dice3.Position = [280 70 51 42];
            else 
                app.dice3.Position = [528 70 51 42];
            end
            app.keptDice(3) = ~app.keptDice(3);
        end

        % Image clicked function: dice4
        function dice4ImageClicked(app, event)
            if app.dice4.Position == [578 70 51 42]
                app.dice4.Position = [330 70 51 42];
            else 
                app.dice4.Position = [578 70 51 42];
            end
            app.keptDice(4) = ~app.keptDice(4);
        end

        % Image clicked function: dice5
        function dice5ImageClicked(app, event)
            if app.dice5.Position == [552 19 51 42]
                app.dice5.Position = [304 19 51 42];
            else
                app.dice5.Position = [552 19 51 42];
            end
            app.keptDice(5) = ~app.keptDice(5);
        end

        % Cell selection callback: UITable
        function UITableCellSelection(app, event)
        indices = event.Indices;
        
        if app.rollCount == 0 % prevents the player from entering a score before rolling
            uialert(app.UIFigure, 'Player must roll first.','Invalid Action')
        elseif app.turnScored == 1 % prevents the player from scoring a roll multiple times
            uialert(app.UIFigure, 'Player has already input a score for their turn. Please start the next turn.', 'Invalid Action')
        elseif indices(2) ~= app.playerTurn+1 % prevents player from entering a score in the opponent's column
            uialert(app.UIFigure, 'Player must input their score in their column. Please select a different spot.','Invalid Action')
        elseif indices(1) == 7 || indices(1) == 8 || indices (1) == 9 || indices(1) == 17 || indices(1) == 18 % prevents player from entering a score in a spot where scores cannot be entered (ex. subtotal, bonus, total, blank spaces, etc.)
            uialert(app.UIFigure, 'Player cannot input scores in this spot. Please select somewhere else.', 'Invalid Action')
        elseif app.UITable.Data{indices(1),app.playerTurn+1} ~= "" % prevents player from entering a score in a spot where a score has already been entered
            uialert(app.UIFigure, 'Player has already input a score here. Please select a different spot','Invalid Action')
        else % scores the player's roll
            %Test Case: app.UITable.Data{indices(1),app.playerTurn+1} = 5;
            %switch indices(1)
            if indices(1) == 1    %case 1
                    app.currentScore = ScoreFunction(app.diceFaces,"ones");
            elseif indices(1) == 2    %case 2
                    app.currentScore = ScoreFunction(app.diceFaces,"twos");
            elseif indices(1) == 3    %case 3
                    app.currentScore = ScoreFunction(app.diceFaces,"threes");
            elseif indices(1) == 4    %case 4
                    app.currentScore = ScoreFunction(app.diceFaces,"fours");
            elseif indices(1) == 5    %case 5
                    app.currentScore = ScoreFunction(app.diceFaces,"fives");
            elseif indices(1) == 6    %case 6
                    app.currentScore = ScoreFunction(app.diceFaces,"sixes");
            elseif indices(1) == 10    %case 10
                    app.currentScore = ScoreFunction(app.diceFaces,"three of a kind");
            elseif indices(1) == 11   %case 11
                    app.currentScore = ScoreFunction(app.diceFaces,"four of a kind");
            elseif indices(1) == 12   %case 12
                    app.currentScore = ScoreFunction(app.diceFaces,"full house");
            elseif indices(1) == 13   %case 13
                    app.currentScore = ScoreFunction(app.diceFaces,"small straight");
            elseif indices(1) == 14   %case 14
                    app.currentScore = ScoreFunction(app.diceFaces,"large straight");
            elseif indices(1) == 15   %case 15
                    app.currentScore = ScoreFunction(app.diceFaces,"yahtzee");
                    app.yahtzeeCount(app.playerTurn) = app.yahtzeeCount(app.playerTurn) + 1;
            elseif indices(1) == 16   %case 16
                    app.currentScore = ScoreFunction(app.diceFaces,"chance");
            end
            
            app.updateTableScores(indices(1),app.currentScore);
            
            %app.turnScored = 1; % prevents player from scoring their turn multiple times if checked                
            app.RollButton.Enable = 'off'; %disables the roll button

            if ~app.localMode
                if app.playerTurn == 2 % updates playerTurn
                    app.playerTurn = 1;
                    app.Player1LitUp.Visible = 'on';
                    app.Player2LitUp.Visible = 'off'; 
                else
                    app.playerTurn = app.playerTurn + 1;
                    app.Player2LitUp.Visible = 'on';
                    app.Player1LitUp.Visible = 'off'; 
                end
                
                if app.playerNumber == 2 && app.turnCount >= 13 
                    playerVictoryAnimation(app); % plays victory animation if applicable
                end

                %ThingSpeak Code to Update Score
                pause(15);
                thingSpeakWrite(app.channelID, 'WriteKey', app.writeKey, 'Fields', [1,2,3,4], 'Values', [indices(1), app.currentScore, app.yahtzeeCount(app.playerTurn), app.playerNumber]);
                
                app.rollCount = 0; % resets rollCount to 0
                app.diceFaces = zeros(1,5); %resets diceFaces for new roll
                
                app.keptDice = false(1,5);
                app.dice1.ImageSource = "one.png"; % returns dice images to original image
                app.dice2.ImageSource = "two.png";
                app.dice3.ImageSource = "three.png";
                app.dice4.ImageSource = "four.png";
                app.dice5.ImageSource = "five.png";
    
                app.dice1.Position = [528 121 51 42]; % returns dice to original positions
                app.dice2.Position = [578 121 51 42];
                app.dice3.Position = [528 70 51 42];
                app.dice4.Position = [578 70 51 42];
                app.dice5.Position = [552 19 51 42];
    
                app.dice1.Enable = 'off'; % turns on keep button for dice
                app.dice2.Enable = 'off';
                app.dice3.Enable = 'off';
                app.dice4.Enable = 'off';
                app.dice5.Enable = 'off';
                
                remotePlayScoring(app);

                app.turnCount = app.turnCount + 1;
            end
            
            %New Turn Code
            if app.localMode % new turn for local play
                if app.playerTurn == 2 % increases turnCount if both players have had a turn
                    app.turnCount = app.turnCount + 1;
                end

                if app.playerTurn == 2 && app.turnCount >= 13
                    playerVictoryAnimation(app);
                end

                app.turnScored = 0; % sets turnScored to false until new turn is scored
                
                app.rollCount = 0; % resets rollCount to 0
                app.diceFaces = zeros(1,5); %resets diceFaces for new roll
    
                app.RollButton.Enable = 'on'; % reenables the roll button
                
                app.keptDice = false(1,5);
                app.dice1.ImageSource = "one.png"; % returns dice images to original image
                app.dice2.ImageSource = "two.png";
                app.dice3.ImageSource = "three.png";
                app.dice4.ImageSource = "four.png";
                app.dice5.ImageSource = "five.png";
    
                app.dice1.Position = [528 121 51 42]; % returns dice to original positions
                app.dice2.Position = [578 121 51 42];
                app.dice3.Position = [528 70 51 42];
                app.dice4.Position = [578 70 51 42];
                app.dice5.Position = [552 19 51 42];
    
                app.dice1.Enable = 'off'; % turns on keep button for dice
                app.dice2.Enable = 'off';
                app.dice3.Enable = 'off';
                app.dice4.Enable = 'off';
                app.dice5.Enable = 'off';
    
                if app.playerTurn == 2 % updates playerTurn
                    app.playerTurn = 1;
                    app.Player1LitUp.Visible = 'on';
                    app.Player2LitUp.Visible = 'off'; 
                else
                    app.playerTurn = app.playerTurn + 1;
                    app.Player2LitUp.Visible = 'on';
                    app.Player1LitUp.Visible = 'off'; 
                end
            else % new turn for ThingSpeak/remote play
                if app.playerNumber == 1 && app.turnCount >= 13
                    playerVictoryAnimation(app); % plays victory animation if applicable
                end
            end

        end

        end

        % Button pushed function: NewGameButton
        function NewGameButtonPushed(app, event)
                if ~app.localMode % resets game for remote play
                    url = sprintf('https://api.thingspeak.com/channels/%s/feeds.json?api_key=%s', num2str(app.channelID), app.userKey); % clears channel for ThingSpeak purposes
                    webwrite(url, weboptions('RequestMethod','delete'));

                    app.playerNumber = 0;
                    app.firstRollScored = false;
                    app.RollButton.Enable = 'off';
                    uialert(app.UIFigure,'Please reselect your player number by clicking on the respective player icon.','Reselect Player 1 or 2')
                end

                app.NewGameButton.Visible = "off"; % hides the new game button until the end of the previous game
                app.NewGameButton.Enable = "off";
            
                %Reset Properties:
                app.rollCount = 0; % tracks the number of rolls
                app.diceFaces = zeros(1,5); % integer array keeping track of the numbers on the faces of the dice for scoring purposes
                app.playerTurn = 1; % track whose turn it is (Player 1 or Player 2)
                app.turnScored = 0; % track whether or not turn has been scored
                app.totalScore = [0,0]; % total score for both players
                app.turnCount = 0; % tracks the number of turns each player has had
                app.yahtzeeCount = [0,0]; % tracks the number of yahtzees for each player
                
                %Table Setup
                Objectives = ["Ones";"Twos";"Threes";"Fours";"Fives";"Sixes";"Bonus (63+)";"Subtotal";"";"Three of a Kind";"Four of a Kind";"Full House";"Small Straight";"Large Straight";"Yahtzee";"Chance";"Yahtzee Bonus";"Total"];
                Player1 = ["";"";"";"";"";"";0;0;"";"";"";"";"";"";"";"";0;0];
                Player2 = ["";"";"";"";"";"";0;0;"";"";"";"";"";"";"";"";0;0];
                app.UITable.Data = table(Objectives, Player1, Player2);
                %To access/change any element in the table:
                %app.UITable.Data{row,column}
                %Note: All Player1 scores are in column 2 and all Player2 scores are in column 3
    
                app.keptDice = false(1,5);
    
                app.dice1.Enable = 'off'; % turns of kept button for dice before the first roll
                app.dice2.Enable = 'off';
                app.dice3.Enable = 'off';
                app.dice4.Enable = 'off';
                app.dice5.Enable = 'off';
    
                app.dice1.Position = [528 121 51 42]; % returns dice to original positions
                app.dice2.Position = [578 121 51 42];
                app.dice3.Position = [528 70 51 42];
                app.dice4.Position = [578 70 51 42];
                app.dice5.Position = [552 19 51 42];
                
                if app.localMode
                    app.RollButton.Enable = 'on'; % reenables the roll button for the next game
                end
    
                                

        end

        % Image clicked function: Player1Icon
        function Player1IconImageClicked(app, event)
            if ~app.localMode
                if app.playerNumber == 0
    
                    app.playerNumber = 1; % sets player number to 1
                    app.RollButton.Enable = 'on'; % allows player to start playing
                end
            end
        end

        % Image clicked function: Player2Icon
        function Player2IconImageClicked(app, event)
            if ~app.localMode   %ThingSpeak Purposes Only
                if app.playerNumber == 0    
                    app.playerNumber = 2; % sets player number to 2
                    app.RollButton.Enable = 'off';
                end
                loopVar = true;
                while loopVar == true && ~app.firstRollScored % checks if player 1 has scored their first turn
                    pause(1);
                    app.currReadVar = thingSpeakRead(app.channelID, 'ReadKey', app.readKey, 'Fields', [1,2,3,4], 'OutputFormat', 'Table');
                    if size(app.currReadVar) ~= 0 & app.currReadVar{1,5} == 1
                            
                            %uialert(app.UIFigure, 'Entered A','');

                            % collect info from opponent/ThingSpeak channel
                            app.yahtzeeCount(app.playerTurn) = app.currReadVar{1,4};
                            app.updateTableScores(app.currReadVar{1,2},app.currReadVar{1,3});
                            app.RollButton.Enable = 'on';
                
                            app.playerTurn = app.playerTurn + 1; 
                            app.Player2LitUp.Visible = 'on';
                            app.Player1LitUp.Visible = 'off'; 
            
                            if app.playerTurn == 2 % increases turnCount if both players have had a turn
                                app.turnCount = app.turnCount + 1;
                            end

                            loopVar = false; % ends the initial score check
                            app.firstRollScored = true; 

                            url = sprintf('https://api.thingspeak.com/channels/%s/feeds.json?api_key=%s', num2str(app.channelID), app.userKey); % clears channel for ThingSpeak purposes
                            webwrite(url, weboptions('RequestMethod','delete'));
                    end

                end
            end
        end

        % Button pushed function: howToPlay
        function howToPlayButtonPushed(app, event)
            uialert(app.UIFigure, 'The Lower-Section combinations are as follows: Three of a Kind (roll three of the same number) (score equals the sum of all five dice), Four of a Kind (roll four of the same number) (score equals the sum of all five dice), Full House (get three of a kind and a pair) (25 pts), Small Straight (four sequential dice) (30 pts), Chance (when none of the above combinations are met) (score is sum of all five dice), Large Straight (five sequential dice) (40 pts), Yahtzee (five of a kind) (50 pts).','How to play Yahtzee (3/3)');
            uialert(app.UIFigure, 'At the end of each turn, you can pick one of 13 combinations for your rolls to fall into. There are many different combinations to accumulate points in Yahtzee. The Upper-Section ones are as follows: Ones (roll as many ones as possible), Twos (roll as many twos), Threes (roll as many threes), Fours (roll as many fours), Fives (roll as many fives), and Sixes (roll as many sixes). For these, the sum of the correct-numbered rolls will be counted to calculate the player’s score. If the player amasses over 63 points, they get a bonus of 35 points added to their score.', 'How to play Yahtzee (2/3)');
            uialert(app.UIFigure, 'You will get three rolls per turn, and 13 turns for a complete game. On each turn, you must roll all five dice during the first roll; however, you can decide which dice to roll on the second and third roll (if you want to keep certain dice values, simply move the dice into the “keep” pile on the bottom right of the screen). The dice that are not in the “keep” pile will be rolled.', 'How to play Yahtzee (1/3)');
            
        end

        % Button pushed function: BGMToggleButton
        function ButtonPushedFcn(app, event)
            if isplaying(app.BGMPlayer)
                app.BGMPlayer.StopFcn = [];
                stop(app.BGMPlayer);
                app.BGMToggleButton.Text = 'Unmute Music';
                app.soundMuted = true;
            else
                app.BGMPlayer = audioplayer(app.BGMData, app.Fs);
                app.BGMPlayer.StopFcn = @(~,~) play(app.BGMPlayer);
                play(app.BGMPlayer);
                app.BGMToggleButton.Text = 'Mute Music';
                app.soundMuted = false;
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Color = [0.3608 0.6549 0.7686];
            app.UIFigure.Position = [100 100 640 480];
            app.UIFigure.Name = 'MATLAB App';

            % Create RollButton
            app.RollButton = uibutton(app.UIFigure, 'push');
            app.RollButton.ButtonPushedFcn = createCallbackFcn(app, @RollButtonPushed, true);
            app.RollButton.BackgroundColor = [0.0667 0.4431 0.7451];
            app.RollButton.FontColor = [1 1 1];
            app.RollButton.Position = [537 172 82 32];
            app.RollButton.Text = 'Roll';

            % Create KeepPileButton
            app.KeepPileButton = uibutton(app.UIFigure, 'push');
            app.KeepPileButton.BackgroundColor = [0.0667 0.4431 0.7451];
            app.KeepPileButton.FontColor = [1 1 1];
            app.KeepPileButton.Position = [280 172 82 32];
            app.KeepPileButton.Text = 'Keep Pile';

            % Create dice5
            app.dice5 = uiimage(app.UIFigure);
            app.dice5.ImageClickedFcn = createCallbackFcn(app, @dice5ImageClicked, true);
            app.dice5.Position = [552 19 51 42];
            app.dice5.ImageSource = 'five.png';

            % Create dice4
            app.dice4 = uiimage(app.UIFigure);
            app.dice4.ImageClickedFcn = createCallbackFcn(app, @dice4ImageClicked, true);
            app.dice4.Position = [578 70 51 42];
            app.dice4.ImageSource = 'four.png';

            % Create dice1
            app.dice1 = uiimage(app.UIFigure);
            app.dice1.ImageClickedFcn = createCallbackFcn(app, @dice1ImageClicked, true);
            app.dice1.Position = [528 121 51 42];
            app.dice1.ImageSource = 'one.png';

            % Create dice2
            app.dice2 = uiimage(app.UIFigure);
            app.dice2.ImageClickedFcn = createCallbackFcn(app, @dice2ImageClicked, true);
            app.dice2.Position = [578 121 51 42];
            app.dice2.ImageSource = 'two.png';

            % Create dice3
            app.dice3 = uiimage(app.UIFigure);
            app.dice3.ImageClickedFcn = createCallbackFcn(app, @dice3ImageClicked, true);
            app.dice3.Position = [528 70 51 42];
            app.dice3.ImageSource = 'three.png';

            % Create Player1Icon
            app.Player1Icon = uiimage(app.UIFigure);
            app.Player1Icon.ImageClickedFcn = createCallbackFcn(app, @Player1IconImageClicked, true);
            app.Player1Icon.Position = [551 397 78 73];
            app.Player1Icon.ImageSource = 'female.jpeg';

            % Create Player2Icon
            app.Player2Icon = uiimage(app.UIFigure);
            app.Player2Icon.ImageClickedFcn = createCallbackFcn(app, @Player2IconImageClicked, true);
            app.Player2Icon.Position = [551 286 78 73];
            app.Player2Icon.ImageSource = 'male.jpeg';

            % Create UITable
            app.UITable = uitable(app.UIFigure);
            app.UITable.ColumnName = {''; 'Player 1'; 'Player 2'};
            app.UITable.RowName = {};
            app.UITable.CellSelectionCallback = createCallbackFcn(app, @UITableCellSelection, true);
            app.UITable.Position = [12 19 256 451];

            % Create Player1Label
            app.Player1Label = uilabel(app.UIFigure);
            app.Player1Label.FontWeight = 'bold';
            app.Player1Label.Position = [567 376 51 22];
            app.Player1Label.Text = 'Player 1';

            % Create Player2Label
            app.Player2Label = uilabel(app.UIFigure);
            app.Player2Label.FontWeight = 'bold';
            app.Player2Label.Position = [567 266 51 22];
            app.Player2Label.Text = 'Player 2';

            % Create playerOneWins
            app.playerOneWins = uiimage(app.UIFigure);
            app.playerOneWins.Position = [12 19 639 479];
            app.playerOneWins.ImageSource = 'playerOneWins.png';

            % Create playerTwoWins
            app.playerTwoWins = uiimage(app.UIFigure);
            app.playerTwoWins.Position = [12 19 639 479];
            app.playerTwoWins.ImageSource = 'playerTwoWins.png';

            % Create Player1LitUp
            app.Player1LitUp = uilabel(app.UIFigure);
            app.Player1LitUp.FontWeight = 'bold';
            app.Player1LitUp.FontColor = [1 1 0];
            app.Player1LitUp.Position = [567 376 51 22];
            app.Player1LitUp.Text = 'Player 1';

            % Create Player2LitUp
            app.Player2LitUp = uilabel(app.UIFigure);
            app.Player2LitUp.FontWeight = 'bold';
            app.Player2LitUp.FontColor = [1 1 0];
            app.Player2LitUp.Position = [567 266 51 22];
            app.Player2LitUp.Text = 'Player 2';

            % Create NewGameButton
            app.NewGameButton = uibutton(app.UIFigure, 'push');
            app.NewGameButton.ButtonPushedFcn = createCallbackFcn(app, @NewGameButtonPushed, true);
            app.NewGameButton.BackgroundColor = [0.0196 0.3608 0.5882];
            app.NewGameButton.FontColor = [0.850980392156863 0.850980392156863 0.850980392156863];
            app.NewGameButton.Position = [280 448 100 22];
            app.NewGameButton.Text = 'New Game';

            % Create howToPlay
            app.howToPlay = uibutton(app.UIFigure, 'push');
            app.howToPlay.ButtonPushedFcn = createCallbackFcn(app, @howToPlayButtonPushed, true);
            app.howToPlay.BackgroundColor = [0.0196 0.3608 0.5882];
            app.howToPlay.FontColor = [0.902 0.902 0.902];
            app.howToPlay.Position = [437 447 101 23];
            app.howToPlay.Text = 'How To Play';

            % Create BGMToggleButton
            app.BGMToggleButton = uibutton(app.UIFigure, 'push');
            app.BGMToggleButton.ButtonPushedFcn = createCallbackFcn(app, @ButtonPushedFcn, true);
            app.BGMToggleButton.BackgroundColor = [0.0196 0.3608 0.5882];
            app.BGMToggleButton.FontColor = [0.902 0.902 0.902];
            app.BGMToggleButton.Position = [437 422 100 22];
            app.BGMToggleButton.Text = 'Mute Music';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = diceGameFinalVersion_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end