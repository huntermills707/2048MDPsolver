
function printBoard(board::UInt64)
    out = zeros(Int32,4,4)
    for i in 1:4
        for j in 1:4
            powerVal = (board) & 0xf
            out[i,j] = (powerVal == 0) ? 0 : 1 << powerVal
            board >>= 4
        end
    end
    show(IOContext(STDOUT, limit=true),"text/plain",out)
    println()
end

ROW_MASK = 0xFFFF
COL_MASK = 0x000F000F000F000

function unpackCol(row::UInt16)
    tmp = row
    return  (tmp | (tmp << 12) | (tmp << 24) | (tmp << 36)) & COL_MASK
end

function reverseRow(row::UInt16)
    return (row >> 12) | ((row >> 4) & 0x00F0)  | ((row << 4) & 0x0F00) | (row << 12);
end

function transpose(x::UInt64)
    a1 = x & 0xF0F00F0FF0F00F0F
    a2 = x & 0x0000F0F00000F0F0
    a3 = x & 0x0F0F00000F0F0000
    a = a1 | (a2 << 12) | (a3 >> 12)
    b1 = a & 0xFF00FF0000FF00FF
    b2 = a & 0x00FF00FF00000000
    b3 = a & 0x00000000FF00FF00
    return b1 | (b2 >> 24) | (b3 << 24)
end

function countEmpty(x::UInt64)
    x |= (x >> 2) & 0x3333333333333333
    x |= (x >> 1)
    x = ~x & 0x1111111111111111
    x += x >> 32
    x += x >> 16
    x += x >>  8
    x += x >>  4
    return x & 0xf
end

function numMoves(board::UInt64)
    out = 0
    for i in 0:3
        if executeMove(i,board) != board
            out += 1
        end
    end
    return out
end

function maxTile(board::UInt64)
    maxrank = 0;
    while (board > 0)
        maxrank = max(maxrank, board & 0xf);
        board >>= 4;
    end
    return maxrank
end

function initTables()
    rowLeftTable = zeros(UInt16, 65536);
    rowRightTable = zeros(UInt16, 65536);
    scoreTable = zeros(Int32,65536);
    squareTable = zeros(65536);
    mono1Table = zeros(65536);
    mono2Table = zeros(65536);

    for row in 0:65535
        row = UInt16(row)
        line = [(row >>  0) & 0xf, (row >>  4) & 0xf, (row >>  8) & 0xf, (row >> 12) & 0xf]
        
        ls = line.^2
        squareTable[row + 1] = sum(ls)

        mono1 = sum(accumulate(max,ls) - ls)
        mono1Table[row+1] = mono1
        mono2 = sum(accumulate(max,ls[end:-1:1]) - ls[end:-1:1])
        mono2Table[row+1] = mono2
        
        score = 0.0
        for i in 1:4
            rank = line[i];
            if rank >= 2
                score += (rank - 1) * (1 << rank);
            end
        end
        scoreTable[row+1] = score;
        
        i = 0
        while i < 3
            j = i+1
            for k in i+1:3
                if line[j+1] != 0
                    break
                end
                j+=1
            end
            if j == 4
                break
            end
            if line[i+1] == 0
                line[i+1] = line[j+1]
                line[j+1] = 0
                i-=1
            elseif line[i+1] == line[j+1]
                if line[i+1] != 0xf
                    line[i+1] += 1
                end
                line[j+1] = 0
            end
            i += 1
        end
            
        result = UInt16((line[1] <<  0) | (line[2] <<  4) | (line[3] <<  8) | (line[4] << 12))
        revResult = reverseRow(result)
        revRow = reverseRow(row)
            
        rowLeftTable[row+1] = row ⊻ result
        rowRightTable[revRow+1] = revRow ⊻ revResult
    end
    
    return rowLeftTable, rowRightTable, scoreTable, squareTable, mono1Table, mono2Table
end  

function scoreBoard(board::UInt64)
    out = 3.25 * maxTile(board)
    out += 4 * countEmpty(board)
    s1 = squareTable[(board >>  0) & ROW_MASK+1] +
         squareTable[(board >> 16) & ROW_MASK+1] +
         squareTable[(board >> 32) & ROW_MASK+1] +
         squareTable[(board >> 48) & ROW_MASK+1]
    out += sqrt(s1)

    m1 = mono1Table[(board >>  0) & ROW_MASK+1] +
         mono1Table[(board >> 16) & ROW_MASK+1] +
         mono1Table[(board >> 32) & ROW_MASK+1] +
         mono1Table[(board >> 48) & ROW_MASK+1]

    m2 = mono2Table[(board >>  0) & ROW_MASK+1] +
         mono2Table[(board >> 16) & ROW_MASK+1] +
         mono2Table[(board >> 32) & ROW_MASK+1] +
         mono2Table[(board >> 48) & ROW_MASK+1]

    board = transpose(board)
    
    m3 = mono1Table[(board >>  0) & ROW_MASK+1] +
         mono1Table[(board >> 16) & ROW_MASK+1] +
         mono1Table[(board >> 32) & ROW_MASK+1] +
         mono1Table[(board >> 48) & ROW_MASK+1]

    m4 = mono2Table[(board >>  0) & ROW_MASK+1] +
         mono2Table[(board >> 16) & ROW_MASK+1] +
         mono2Table[(board >> 32) & ROW_MASK+1] +
         mono2Table[(board >> 48) & ROW_MASK+1]

    out -= 1.75 * sqrt(minimum([m1 + m3, m1 + m4, m2 + m3, m2 + m4]))
end

function executeMove0(board::UInt64)
    ret = board;
    t = transpose(board);
    ret = ret ⊻ UInt64(rowLeftTable[(t >>  0) & ROW_MASK+1]) <<  0;
    ret = ret ⊻ UInt64(rowLeftTable[(t >> 16) & ROW_MASK+1]) << 16;
    ret = ret ⊻ UInt64(rowLeftTable[(t >> 32) & ROW_MASK+1]) << 32;
    ret = ret ⊻ UInt64(rowLeftTable[(t >> 48) & ROW_MASK+1]) << 48;
    return transpose(ret)
end

function executeMove1(board::UInt64)
    ret = board;
    t = transpose(board);
    ret = ret ⊻ colDownTable[(t >>  0) & ROW_MASK+1] <<  0;
    ret = ret ⊻ colDownTable[(t >> 16) & ROW_MASK+1] <<  4;
    ret = ret ⊻ colDownTable[(t >> 32) & ROW_MASK+1] <<  8;
    ret = ret ⊻ colDownTable[(t >> 48) & ROW_MASK+1] << 12;
    return ret
end

function executeMove2(board)
    ret = board;
    ret = ret ⊻ UInt64(rowLeftTable[(board >>  0) & ROW_MASK+1]) <<  0;
    ret = ret ⊻ UInt64(rowLeftTable[(board >> 16) & ROW_MASK+1]) << 16;
    ret = ret ⊻ UInt64(rowLeftTable[(board >> 32) & ROW_MASK+1]) << 32;
    ret = ret ⊻ UInt64(rowLeftTable[(board >> 48) & ROW_MASK+1]) << 48;
    return ret
end

function executeMove3(board::UInt64)
    ret = board;
    ret = ret ⊻ UInt64(rowRightTable[(board >>  0) & ROW_MASK+1]) <<  0;
    ret = ret ⊻ UInt64(rowRightTable[(board >> 16) & ROW_MASK+1]) << 16;
    ret = ret ⊻ UInt64(rowRightTable[(board >> 32) & ROW_MASK+1]) << 32;
    ret = ret ⊻ UInt64(rowRightTable[(board >> 48) & ROW_MASK+1]) << 48;
    return ret
end

function executeMove(move, board::UInt64)
    if move == 0
        return transpose(executeMove2(transpose(board)))
    elseif move == 1
        return transpose(executeMove3(transpose(board)))
    elseif move == 2
        return executeMove2(board)
    elseif move == 3
        return executeMove3(board)
    else
        return ~UInt64(0)
    end
end

function insertRandTile(board::UInt64, tile = UInt64((rand() < .9) ? 1 : 2))
    index = rand(1:countEmpty(board));
    j = 0
    tmp = board;
    for i in 1:16
        if ((tmp & 0xf) == 0)
            j+=1
        end
        if j == index
            break
        end
        tmp >>= 4;
        tile <<= 4;
    end
    return board | tile
end

function insertTile(board::UInt64, tile::UInt64, index::UInt64)
    j = UInt64(0)
    tmp = board;
    for i in 1:16
        if ((tmp & 0xf) == 0)
            j+=1
        end
        if j == index
            break
        end
        tmp >>= 4;
        tile <<= 4;
    end
    return board | tile
end


function scoreGame(board::UInt64)
    return scoreTable[(board >>  0) & ROW_MASK+1] +
           scoreTable[(board >> 16) & ROW_MASK+1] +
           scoreTable[(board >> 32) & ROW_MASK+1] +
           scoreTable[(board >> 48) & ROW_MASK+1]
end

function initGame()
    board = UInt64(0)
    board = UInt64((rand() < .9) ? 1 : 2) << (4 * rand(0:15))
    board = insertRandTile(board)
    return board
end

function gameOver(board::UInt64)
    for i in 0:3
        if board != executeMove(i,board)
            return false
        end
    end
    return true
end

function runGame(getMove, printOut)
    turnNum = 1
    game = initGame()
    while (true)
        m = getMove(game)
        if gameOver(game)
            break
        end
        game = executeMove(m,game)
        game = insertRandTile(game)
        if printOut == true
            println(m," ",scoreGame(game))
            printBoard(game)
        end
        turnNum += 1
    end
    return 2 ^ maxTile(game), scoreGame(game), turnNum
end

function randMove(board::UInt64)
    for i in randperm(4)
        if executeMove(i-1,board) != board
            return i-1
        end
    end
    return -1
end

function greedyMove(board::UInt64)
    astar = -1; vstar = -1000000
    for i in randperm(4)
        cboard = executeMove(i-1,board) 
        if cboard!= board
            v = scoreBoard(cboard)
            if v > vstar
                vstar = v
                astar = i - 1
            end
        end
    end
    return astar
end