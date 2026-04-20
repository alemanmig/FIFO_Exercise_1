# Activate Signal List Panel
srcSignalView -on
verdiSetActWin -dock widgetDock_<Signal_List>

# Add Digital Signals
srcSignalViewSelect "tb.dut.clk_i"
srcSignalViewAddSelectedToWave
srcSignalViewSelect "tb.dut.rst_i"
srcSignalViewAddSelectedToWave
srcSignalViewSelect "tb.dut.d_i\[7:0\]"
srcSignalViewAddSelectedToWave
srcSignalViewSelect "tb.dut.q_o\[7:0\]"
srcSignalViewAddSelectedToWave

# Zoom to fit
verdiSetActWin -win $_nWave2
wvZoomAll -win $_nWave2
