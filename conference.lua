luasql =require "luasql.postgres"

-- Set the database connection parameters
local dbname = "testdb"
local username = "postgres"
local password = "Manju#123"
local host = "localhost"
local port = 5432 -- Default PostgreSQL port


attempt = 1
max_attempts = 3

function get_conference_num(min, max, attempts, timeout)
  local conference_num
  freeswitch.consoleLog("NOTICE", "Awaiting caller to enter a conference number phrase:conference_num\n")
  conference_num = session:playAndGetDigits(min, max, attempts, timeout, '#', '/usr/local/freeswitch/sounds/en/us/callie/conference/8000/conf-enter_conf_number.wav', '', '\\d+')
  return(conference_num)
end

function get_conference_pin(min, max, attempts, timeout, pin_number)
  local pin_attempt = 1
  local pin_max_attempt = 3

  while pin_attempt <= pin_max_attempt do
    conference_pin = session:playAndGetDigits(min, max, attempts, timeout, '#', '/usr/local/freeswitch/sounds/en/us/callie/conference/8000/conf-pin.wav', '', '\\d+')
    if tonumber(conference_pin) == tonumber(pin_number) then
      return true
    else
      session:execute("playback", "/usr/local/freeswitch/sounds/en/us/callie/conference/8000/conf-bad-pin.wav")
    end

    pin_attempt = pin_attempt + 1
  end

  return false
end


-- Create the environment and connection
 env = assert(luasql.postgres())
 db_connection = assert(env:connect(dbname, username, password, host, port))


session:answer();


if session:ready() then
  freeswitch.consoleLog("NOTICE", string.format("Caller has called conferencing server, Playing welcome message phrase:conference_welcome\n"))
  session:execute("playback", "/usr/local/freeswitch/sounds/en/us/callie/conference/8000/conf-welcome.wav")
end

while attempt <= max_attempts do
  conf_num = get_conference_num(1, 4, 3, 4000)
--  conf_num = 1
  db_cursor = assert(db_connection:execute(string.format("select conf_pin from conferences where conf_num = %d", tonumber(conf_num))))
  row = db_cursor:fetch({}, "a")

  --[[ do conference authentication ]]--
  if row == nil then
    --[[ if the conference number does not exist, playback message saying it is
         and invalid conference number ]]--
    session:execute("playback", "/usr/local/freeswitch/sounds/en/us/callie/conference/8000/conf-bad-pin.wav")

  elseif row["conf_pin"] == nil or row["conf_pin"] == "" then
    freeswitch.consoleLog("NOTICE", string.format("Conference %d has no PIN, Sending caller into conference\n", tonumber(conf_num)))
    --[[ join the conference ]]--
    session:execute("conference", string.format("%s@default", conf_num))

  else
    freeswitch.consoleLog("NOTICE", string.format("Conference %d has a PIN %d, Authenticating user\n", tonumber(conf_num), tonumber(row["conf_pin"])))

    --[[ get the conference pin number ]]--
  if ((get_conference_pin(1, 4, 3, 4000, row["conf_pin"])) == true) then
    freeswitch.consoleLog("NOTICE", string.format("Conference %d correct PIN entered, Sending caller into conference\n", tonumber(conf_num)))
      --[[ join the conference, if the correct pin was entered ]]--
    session:execute("conference", string.format("%s@default", conf_num))

  else
    freeswitch.consoleLog("NOTICE", string.format("Conference %d invalid PIN entered, Looping again\n", tonumber(conf_num)))
    end
  end

  attempt = attempt + 1
end
--conference_too_many_failures
session:execute("playback", "/usr/local/freeswitch/sounds/en/us/callie/conference/8000/conf-goodbye.wav")

session:hangup()
