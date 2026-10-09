package require ::quartus::stp

open_session -name stp2.stp
if {[catch {
    run -instance auto_signaltap_0 \
        -signal_set {signal_set: 2026/09/09 19:21:53  #0} \
        -trigger {trigger: 2026/09/09 19:21:53  #1} \
        -data_log online_test -timeout 30
    export_data_log -instance auto_signaltap_0 \
        -signal_set {signal_set: 2026/09/09 19:21:53  #0} \
        -trigger {trigger: 2026/09/09 19:21:53  #1} \
        -data_log online_test -filename output_files/online_test.csv -format csv
} message]} {
    puts "ONLINE_CAPTURE_ERROR: $message"
    close_session
    exit 1
}
puts "ONLINE_CAPTURE_OK"
close_session
