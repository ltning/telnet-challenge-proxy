-- ****************************************************
-- *** Nginx/LUA stream module "CAPTCHA" for Telnet ***
-- ****************************************************

-- Steal the socket to the connecting client
local sock = assert(ngx.req.socket(true))
-- Get ourselves some randomness, use the system time as a rudimentary seed
-- (otherwise we'd be asking the same question every time we restart nginx).
math.randomseed(os.time())
-- Generate the actual math quiz..
local num1 = math.random(1,8)
local num2 = math.random(1,9-num1)
-- ...we should probably know the answer, too..
local ans = num1+num2

-- IMPORTANT: This number tells the script how many active connections to
-- allow; it *must* be the same as the sum of max_conn settings for the
-- upstreams defined in nginx.conf!
local max_conns = 2

-- Access the shared DICT for the active user counter, for later use
local users = ngx.shared.users

-- Use 'ngx.say()' to talk to the connecting client. This function will add
-- a newline ('\n') to the end of each line, but we need to add the carriage
-- return as well, since, well, DOS and Windows and whatnot. Start with a
-- couple blank lines to make sure the text is easy to read.
ngx.say("\r\n\r")
ngx.say("Hello!\r\n\r")

-- Now we need to determine if we can even accept this visitor; if we can
-- not, try to be polite about it. First we fetch the current number of
-- active users..
local usercount = users:get("active")
-- ..then we compare to the max_conns variable we set above:
if usercount and usercount >= max_conns then
    -- Give a reasonable error message..
    ngx.say("    Too many active users, sorry! Try again later!\r\n\r")
    ngx.say("    (While you wait, check out http://floppy.museum/bbs.htm !)\r\n\r")
    -- Sleep a couple of sconds in case the user's terminal clears the
    -- screen on disconnect (or to tie up resources if there's a scanner
    -- or bot attempting to connect) - then exit:
    ngx.sleep(3)
    ngx.exit(400)
end

-- If we made it here, all is presumably good (it can still go wrong if we
-- have other guests arriving while the challenge is being handled, but
-- we'll worry about that after the challenge.)
ngx.say("\r")
ngx.say("   =====================================================   \r")
ngx.say("   If you experience trouble, especially with the mail-\r")
ngx.say("   to-sysop, let me know (@ltning@pleroma.anduin.net) or\r")
ngx.say("   ltning AT anduin dot net.\r")
ngx.say("   =====================================================   \r")
ngx.say("\r")
ngx.say("To make sure you're human, please answer this simple question:\r")
ngx.say("    If you have ", num1, " modems, then your friendly but a bit weird aunt\r")
ngx.say("    gives you ", num2, " more, how many BBS nodes can you spin up (assuming\r")
ngx.say("    you have enough serial ports)?\r")
ngx.say("\r")
-- Use 'ngx.print()' this time, as we specifically do *not* want a newline
-- after the prompt..
ngx.print("(Count your modems and hit ENTER): ")

-- Read a single line of data from the client, presumably the answer to our
-- quiz.
-- local data = sock:receive(1)
local data
local reader = sock:receiveuntil("\n")
local _data, err, partial = reader(1)
if err then
    ngx.say("failed to read the data stream: ", err)
else
    local strval = string.byte(_data)
    if strval >= 128 then
        local junk, err, partial = reader(5)
        if err then
            ngx.say("failed to read the data stream: ", err)
        end
        _data, err, partial = reader(1)
        strval = string.byte(_data)
        -- ngx.say("first read chunk: [", _data, ",", strval, "]\r")
    end

    while true do
        if not _data then
            if err then
                ngx.say("failed to read the data stream: ", err)
                break
            end
            -- ngx.say("read done")
            break
        end
        strval = string.byte(_data)
        if strval == 13 or strval == 0 then
            -- ngx.say("read done")
            break
        else
            ngx.print(_data)
            data = _data
        end
        -- ngx.say("read chunk: [", string.byte(data), ",", strval, "]\r")
        _data, err, partial = reader(1)
    end
end

-- Pick any consecutive number of digits from the given answer.
-- string.find(): %d+ represents 'digits, one or more'.
-- Wrapping that in (..) captures the first instance into the 'res'
-- variable (the two '_' variables are throwaways).
local res, _
if data ~= nil then
    -- Only do all this if there are actual data to be read.
    _,_,res = string.find(data, "(%d+)")
else
    -- Not sure if we should be polite here; it'll usually either be
    -- network scans (benign or not) or script kiddies hitting..
    ngx.say("\r\n\rSomething went wrong and no data was received.\r\n\r")
    ngx.exit(400)
end

-- Compare the given answer to our precomputed one. Make sure the answer is
-- cast into a number, otherwise the comparison will fail.
if tonumber(res) == ans then
    -- Check again whether we have capacity for this user (in case someone
    -- else connected in the meantime)
    local usercount = users:get("active")
    if usercount and usercount >= max_conns then
        ngx.say("\r\n\rSorry, but someone arrived before you could answer, and now all nodes are busy.\r")
        ngx.say("Please try again soon!\r\n\r")
        ngx.say("(While you wait, check out http://floppy.museum/bbs.htm !)\r\n\r")
        ngx.exit(429)
    else
        -- Increase the shared counter (see nginx.conf)
        local newval, err = users:incr("active", 1, 0)
        if err then
            ngx.log(ngx.ERR, "Failed to increase user count: ", err)
            ngx.exit(500)
        end

        -- Confirm to the user
        ngx.say("\r\n\rYou lucky duck, you! Now step into my office..\r\n\r")
        -- Set the nginx variable (which is connection-local) indicating
        -- the user might be human
        ngx.var.bbs_challenge_passed = 1
        -- then continue to end of script.
    end

-- Here we're checking if the answer is actually a number, and if it is..
elseif tonumber(res) then
    -- ..we gently mock the math skills of our guest.
    ngx.say("\r\n\rBLEEP! ", tostring(res), " ?? Try again after brushing up on your maths..\r\n\r")
    -- Wait for a few seconds (to slow down bots that hammer us)
    ngx.sleep(3)
    -- Exit with 403 (which is meaningless here, but the ngx.exit() function
    -- needs an exit code)
    ngx.exit(403)

-- The answer did not contain a number, so we're assuming it is nonsensical.
else
    -- Tell the user to give us a sensible answer next time.
    ngx.say("\r\n\rBLEEP! Try entering an actual number next time!\r\n\r")
    -- Wait for a few seconds (to slow down bots that hammer us)
    ngx.sleep(3)
    -- Exit with 403 (which is meaningless here, but the ngx.exit() function
    -- needs an exit code)
    ngx.exit(403)
end
