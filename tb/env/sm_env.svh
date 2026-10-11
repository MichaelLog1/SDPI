class sm_env #(
    parameter int unsigned NUM_FRAMES = 1000
);
    virtual sm_core_if vif;
    mailbox #(sm_program) frame_driver_mailbox;
    mailbox #(sm_obs) scoreboard_mailbox;

    sm_frame_driver driver;
    sm_monitor monitor;
    sm_scoreboard scoreboard;

    function new(virtual sm_core_if _vif);
        vif = _vif;
        frame_driver_mailbox = new;
        scoreboard_mailbox = new;

        driver = new(vif, frame_driver_mailbox);
        monitor = new(vif, scoreboard_mailbox);
        scoreboard = new(scoreboard_mailbox);
    endfunction

    task generate_frames();
        sm_program_sequence seq;
        smoke_seq s_seq;

        s_seq = new();

        for (int i = 0; i < NUM_FRAMES; i++) begin
            randcase
                100 : seq = s_seq;
            endcase
            seq.body(frame_driver_mailbox);
        end

        // insert sentinal value
        frame_driver_mailbox.put(null);
    endtask

    task run();
        fork
            monitor.run();
            scoreboard.run();
            generate_frames();
        join_none

        driver.run();
        do @(posedge vif.clk); while (scoreboard_mailbox.num() != 0);
        repeat (5) @(posedge vif.clk);
        $display("\nPassed: %d\nFailed: %d\n", scoreboard.passed, scoreboard.failed);
        if (scoreboard.failed > 0) begin
            $fatal(1, "Fail.");
        end else if (scoreboard.passed == 0 && scoreboard.failed == 0) begin
            $fatal(1, "No checks performed.");
        end else begin
            $display("Pass.");
        end
        $finish(0);
    endtask
endclass