-- gcode lines generator

-- Forward declaration for the calculateSize() function below
its = 0

-- This is the array that will hold all the generated lines
lines = {}

-- For Mach3, we have line numbers and this is
-- the first line number in our gcode
currentGCodeLine = 10
-- Number to increment by
lineIncrement = 10

-- The amount of space between the lines
incrementY = 0.2468


-- Calculate the amount of material we need
function calculateSize()
    -- We calculate the width by the number of 
    -- iterations * incrementY
    width = its * incrementY
    width = width + 1 -- +1 the border on both sides
    
    height = len + 1 -- +1 for the border on both sides

    return width, height
end

-- Convienence function for the current date/time
function getCurrentDateTime()
    return os.date("%m/%d/%y - %H:%M:%S")
end

-- This function adds the gcode line to the array with the
-- line number prepended (for Mach3)
function writeLine(gcodeLine)
    line = string.format("%04d %s", currentGCodeLine, gcodeLine)
    table.insert(lines, line)
    currentGCodeLine = currentGCodeLine + lineIncrement
end

function writePreamble()
    writeLine("G20")
	writeLine("F1")
	writeLine("G53 G90 G40") -- g90 absolute positioning
	writeLine("M666 (THC OFF)")
end

function writePostlude()
    -- Put us back at 0,0
	writeLine("X0.0000 Y0.0000") -- this is part of the G00 above

	-- and finish
    writeLine("M04 M30")
end

io.write("Name or identifier: ")
ident = io.read()
io.write("Gauge you're cutting: ")
gauge = io.read()
io.write("Length of cuts (Inches): ")
len = io.read("*n")
io.write("Starting Inches Per Minute (IPM): ")
ipm = io.read("*n")
io.write("IPM increment: ")
inc = io.read("*n")
io.write("Iterations: ")
its = io.read("*n")

-- Repeat it back to the user
io.write("Writing " .. gauge .. " gauge coupon of " .. len .. "\" length, IPM of " .. ipm .. ", incrementing by " .. inc .. " for " .. its .. " iterations\n")

-- Now let's figure out how big this is gonna be and prompt the user to
-- verify that they have a piece of material big enough for this coupon
width, height = calculateSize()

io.write("Make sure you have a piece of material that is " .. width .. "\" x " .. height .. "\"!\n")


--
-- Okay, let's start putting a program together
--

writeLine("(" .. ident .. ")")
writeLine("(Created on " .. getCurrentDateTime() .. ")")
writeLine("(Settings:)")
writeLine("(    gauge: " .. gauge .. ")")
writeLine("(    length: " .. len .. ")")
writeLine("(    starting IPM: " .. ipm .. ")")
writeLine("(    IPM increment: " .. inc .. ")")
writeLine("(    iterations: " .. its .. ")")

-- The preamble is the stuff that is necessary to set the 
-- machine up
writePreamble()

-- Now we begin the actual loop
currentY = 0.0
currentIPM = ipm
for i = 1, its do
    writeLine(string.format("(Pass %d - Y is %.4f and IPM is %.2f)", i, currentY, currentIPM))
    writeLine(string.format("G00 X0.0000 Y%.4f", currentY))
    writeLine("G31 Z -100 F19.685")
    writeLine("G92 Z0.0 (Set Z 0)")                  -- Set Z 0
    writeLine("G00 Z0.1000 (Lift up a little)")      -- lift up a little from the table...also something to look into
    writeLine("G92 Z0.0 (Set Z to 0 again)")         -- Set Z 0 again
    writeLine("G00 Z0.1500 (Move to pierce height)") -- Move to pierce height
    writeLine("M667 (THC ON)")                       -- THC on
    writeLine("M03 (TORCH ON)")                      -- This turns the torch on
    writeLine("G04 P0.0 (Pierce Delay)")             -- Pierce delay
    writeLine("G00 Z0.0600 (Move to cut height)")    -- Move to cut height

    -- Now start moving
    writeLine(string.format("G01 X3.7300 F%.2f (Do the move at F%.2f)", currentIPM, currentIPM))
    writeLine("M04 (TORCH OFF)") -- Torch off
    writeLine("M666 (THC OFF)")  -- thc off

    -- move up
    writeLine("G00 Z1.5000 (Move up and out of the way)")

    -- Now increment where we are
    currentY = currentY + incrementY
    -- Now increment the ipm value
    currentIPM = currentIPM + inc
end

-- And now wrap it up
writePostlude()
    
-- Now write it out to a file
filename = string.format("%s-%dga-%dipm.tap", ident, gauge, ipm)
file = io.open (filename, "w")
for k,v in ipairs(lines) do
    io.output(file)
    io.write(v .. "\n")
end
io.close(file)

