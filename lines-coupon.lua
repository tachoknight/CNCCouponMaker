-- gcode lines generator

-------------------------------------------------------------------------------
-- Variables
-------------------------------------------------------------------------------

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

-------------------------------------------------------------------------------
-- Helper functions
-------------------------------------------------------------------------------

-- Calculate the amount of material we need
function calculateSize()
    -- We calculate the width by the number of 
    -- iterations * incrementY
    height = its * incrementY
    height = height + 1 -- +1 the border on both sides
    
    width = len + 1 -- +1 for the border on both sides

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

-- This function adds the gcode to set the torch up; we 
-- find Z and then reposition the torch, then turn it on
function prepareToCut()
    writeLine("G31 Z -100 F19.685")
    writeLine("G92 Z0.0 (Set Z 0)")                  -- Set Z 0
    writeLine("G00 Z0.1000 (Lift up a little)")      -- lift up a little from the table...also something to look into
    writeLine("G92 Z0.0 (Set Z to 0 again)")         -- Set Z 0 again
    writeLine("G00 Z0.1500 (Move to pierce height)") -- Move to pierce height
    writeLine("M667 (THC ON)")                       -- THC on
    writeLine("M03 (TORCH ON)")                      -- This turns the torch on
    writeLine("G04 P0.0 (Pierce Delay)")             -- Pierce delay
    writeLine("G00 Z0.0600 (Move to cut height)")    -- Move to cut height
end

function turnTorchOff()
    writeLine("M04 (TORCH OFF)") -- Torch off
    writeLine("M666 (THC OFF)")  -- THC off
     -- move up
     writeLine("G00 Z1.5000 (Move up and out of the way)")
end

-- Commands to set the machine up for our job
function writePreamble()
    writeLine("G20")
	writeLine("F1")
	writeLine("G53 G90 G40") -- g90 absolute positioning
	writeLine("M666 (THC OFF)")
end

function makeArrow(ipm)
    writeLine("(-----)")
    writeLine(string.format("(Now cutting the direction arrow at %.2f)", ipm))
    writeLine("(-----)")

    -- Get the size, we're going to make the arrow above the cuts
    width, height = calculateSize()
    writeLine(string.format("G00 X%.2f Y%.2f", width - 0.5, 0.5))    
    prepareToCut()
    -- Cut the main arrow line
    writeLine(string.format("G01 X%.2f Y%.2f", width - 0.5, height - 0.5))
    -- Now the left line
    writeLine(string.format("G01 X%.2f Y%.2f", width - 0.5 - 0.2, height - 0.5 - 0.3))
    turnTorchOff()
    -- Go back
    writeLine(string.format("G00 X%.2f Y%.2f", width - 0.5, height - 0.5))
    prepareToCut()
    -- Now the right line
    writeLine(string.format("G01 X%.2f Y%.2f", width - 0.5 + 0.2, height - 0.5 - 0.3))

    turnTorchOff()
end

-- This function adds a border around the coupon so 
-- we don't have to lift up the entire piece of material.
-- This function takes a parameter of IPM because we aren't
-- sure what is a "good" value yet (that's after we're done)
-- so it gets passed in below
function makeBorder(ipm)
    -- Get how big the square should be
    width, height = calculateSize()

    -- Reset to X,Y 0
    writeLine("(-----)")
    writeLine(string.format("(Now cutting the border at %.2f)", ipm))
    writeLine("(-----)")
    writeLine("G00 X0.0000 Y0.0000")
    prepareToCut()
    -- Now cut the square border
    writeLine(string.format("G01 X%.2f F%.2f (Do the move at F%.2f)", width, ipm, ipm))
    writeLine(string.format("G01 Y%.2f F%.2f (Do the move at F%.2f)", height, ipm, ipm))
    writeLine(string.format("G01 X0 F%.2f (Do the move at F%.2f)", ipm, ipm))
    writeLine(string.format("G01 Y0 F%.2f (Do the move at F%.2f)", ipm, ipm))

    turnTorchOff()
end 

-- Write out the commands at the end to properly reset
-- the machine
function writePostlude()
    -- Put us back at 0,0
	writeLine("G0 X0.0000 Y0.0000") -- this is part of the G00 above

	-- and finish
    writeLine("M04 M30")
end

-------------------------------------------------------------------------------
-- Program begins here
-------------------------------------------------------------------------------

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
currentY = 0.75
currentX = 0.75
currentIPM = ipm
for i = 1, its do
    writeLine(string.format("(Pass %d - Y is %.4f and IPM is %.2f)", i, currentY, currentIPM))
    -- The offsetX is so that the cuts are within the border that we're going to cut out
    -- at the end
    writeLine(string.format("G00 X%.2f Y%.4f", currentX, currentY))
    
    prepareToCut()

    -- Now start moving
    writeLine(string.format("G01 X%.2f F%.2f (Do the move at F%.2f)", len, currentIPM, currentIPM))
   
    -- And now turn the torch off
    turnTorchOff()

    -- Now increment where we are
    currentY = currentY + incrementY
    -- Now increment the ipm value
    currentIPM = currentIPM + inc
end

-- Arrow to indicate the direction of the cuts
makeArrow(ipm)

-- Cut a border around the piece using the initial IPM value
makeBorder(ipm)

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

