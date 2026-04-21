# Activate Signal List Panel
srcSignalView -on
verdiSetActWin -dock widgetDock_<Signal_List>

# Add Digital Signals
srcSignalViewSelect "tb.dut.clk"
srcSignalViewAddSelectedToWave
srcSignalViewSelect "tb.dut.rst_n"
srcSignalViewAddSelectedToWave
srcSignalViewSelect "tb.dut.write_en"
srcSignalViewAddSelectedToWave
srcSignalViewSelect "tb.dut.read_en"
srcSignalViewAddSelectedToWave
srcSignalViewSelect "tb.dut.write_data[7:0]"
srcSignalViewAddSelectedToWave
srcSignalViewSelect "tb.dut.read_data[7:0]"
srcSignalViewAddSelectedToWave
srcSignalViewSelect "tb.dut.count"
srcSignalViewAddSelectedToWave
srcSignalViewSelect "tb.dut.write_ptr"
srcSignalViewAddSelectedToWave
srcSignalViewSelect "tb.dut.read_ptr"
srcSignalViewAddSelectedToWave
srcSignalViewSelect "tb.dut.wr_en_eff"
srcSignalViewAddSelectedToWave
srcSignalViewSelect "tb.dut.rd_en_eff"
srcSignalViewAddSelectedToWave
srcSignalViewSelect "tb.dut.full"
srcSignalViewAddSelectedToWave
srcSignalViewSelect "tb.dut.empty"
srcSignalViewAddSelectedToWave
srcSignalViewSelect "tb.dut.almost_full"
srcSignalViewAddSelectedToWave
srcSignalViewSelect "tb.dut.almost_empty"
srcSignalViewAddSelectedToWave

# Zoom to fit
verdiSetActWin -win $_nWave2
wvZoomAll -win $_nWave2
