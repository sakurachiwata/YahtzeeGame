% 'Ones, Twos, Threes, Fours, Fives, Sixes, Subtotal, Bonus, Three of a Kind, Four of a Kind, Full House, Small Straight, Large Straight, Yahtzee, Bonus Yahtzee, Total'};

% Test code (script section)
%dice = [1, 2, 1, 5, 6];
%score = ScoreFunctions(dice, "ones");
%disp(score)

% Main function
function score = ScoreFunction(dice, category)
    switch category
        case "ones"
            score = CountOnes(dice);
        case "twos"
            score = CountTwos(dice);
        case "threes"
            score = CountThrees(dice);
        case "fours"
            score = CountFours(dice);
        case "fives"
            score = CountFives(dice);
        case "sixes"
            score = CountSixes(dice);
        case "subtotal"
            score = CountSub(dice);
        case "three of a kind"
            score = CountKindThree(dice);
        case "four of a kind"
            score = CountKindFour(dice);
        case "full house"
            score = CountFullHouse(dice);
        case "small straight"
            score = CountSS(dice);
        case "large straight"
            score = CountLS(dice);
        case "yahtzee"
            score = CountYahtzee(dice);
        case "yahtzee bonus"
            score = CountYahtzeeWithBonus(dice);
        case "chance"
            score = sum(dice);
        otherwise
            score = 0;
    end
end

% Subfunctions
function ones = CountOnes(dice)
    ones = sum(dice == 1) .* 1;
end

function twos = CountTwos(dice)
    twos = sum(dice == 2) * 2;
end

function threes = CountThrees(dice)
    threes = sum(dice == 3) * 3;
end

function fours = CountFours(dice)
    fours = sum(dice == 4) * 4;
end

function fives = CountFives(dice)
    fives = sum(dice == 5) * 5;
end

function sixes = CountSixes(dice)
    sixes= sum(dice == 6) * 6;
end

function subtotal = CountSub(dice)
    subtotal = sum(dice);

    if subtotal >= 63
        subtotal = subtotal + 35;
    end
end

function kindThree = CountKindThree(dice)
    [~,freq] = mode(dice);
    if freq >= 3
        kindThree = sum(dice);
    else
        kindThree = 0;
    end
end 

function kindFour = CountKindFour(dice)
    [~,freq] = mode(dice);
    if freq >= 4
        kindFour = sum(dice);
    else
        kindFour = 0;
    end
end 

function fullHouse = CountFullHouse(dice)
    counts = histcounts(dice, 1:7);  % Counts how many of each number (1–6)
    
    if any(counts == 3) && any(counts == 2)
        fullHouse = 25;  % Full House score in Yahtzee
    else
        fullHouse = 0;
    end
end

function smallStraight = CountSS(dice)
    smallStraight = 0; % default
    uniqueDice = unique(dice);  % remove duplicates and sort

    % Define possible small straights
    patterns = [
        1 2 3 4;
        2 3 4 5;
        3 4 5 6
    ];

    for i = 1:size(patterns,1)
        if all(ismember(patterns(i,:), uniqueDice))
            smallStraight = 30;
            return
        end
    end
end

function largeStraight = CountLS(dice)
    largeStraight = 0; % default
    uniqueDice = unique(dice);

    if isequal(uniqueDice, [1 2 3 4 5]) || isequal(uniqueDice, [2 3 4 5 6])
        largeStraight = 40;
    end
end

function yahtzeeScore = CountYahtzee(dice)
    if all(dice == dice(1))
        yahtzeeScore = 50;
    else
        yahtzeeScore = 0;
    end
end

function [yahtzeeScore, bonusYahtzee] = CountYahtzeeWithBonus(dice, yahtzeeAlreadyScored)
    if all(dice == dice(1))  % Check if all 5 dice are the same
        if yahtzeeAlreadyScored
            yahtzeeScore = 0;        % Don't give 50 again
            bonusYahtzee = 100;      % Bonus Yahtzee points
        else
            yahtzeeScore = 50;       % First Yahtzee
            bonusYahtzee = 0;
        end
    else
        yahtzeeScore = 0;
        bonusYahtzee = 0;
    end
end


    
