##=============================================================================
## [Filename]       run.tcl
## [Project]        -
## [Author]         Ciro Bermudez - cirofabian.bermudez@gmail.com
## [Language]       Tcl (Tool Command Language)
## [Created]        Nov 2024
## [Modified]       -
## [Description]    Tcl file fo run simulation
## [Notes]          This file is passed to the ./simv command 
##                  using the -ucli -do run.tcl flag
## [Status]         stable
## [Revisions]      -
##=============================================================================

# Dump signals to FSDB (RECOMMENDED)
dump -file novas.fsdb -type FSDB
dump -add tb.dut -depth 1 -ports -fid FSDB0
run
quit

# Dump signals to FSDB (RECOMMENDED)
# dump -file novas.fsdb -type FSDB
# dump -add tb.* -depth 0 -fid FSDB0 -aggregates
# run
# quit

# Dumps everything from root including complex data type 
# dump -file novas.fsdb -type FSDB
# dump -add / -aggregates
# run
# quit
