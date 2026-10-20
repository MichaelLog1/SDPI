class sm_env #(
    parameter int unsigned NUM_FRAMES = 1000
);
    virtual sm_core_if vif;
    mailbox #(sm_program) frame_driver_mailbox;
    mailbox #(sm_obs) scoreboard_mailbox;

    sm_frame_driver driver;
    sm_monitor monitor;
    sm_scoreboard scoreboard;
    sm_pin_agent pin_agent;
    sm_tx_agent tx_agent;
    sm_rx_agent rx_agent;

    function new(virtual sm_core_if _vif);
        vif = _vif;
        frame_driver_mailbox = new;
        scoreboard_mailbox = new;

        driver = new(vif, frame_driver_mailbox);
        monitor = new(vif, scoreboard_mailbox);
        scoreboard = new(scoreboard_mailbox);
        pin_agent = new(vif);
        tx_agent = new(vif);
        rx_agent = new(vif);
    endfunction

    task generate_frames();
        sm_program_sequence seq;
        smoke_seq smoke;
        pull_seq pull;
        push_seq push;
        rand_seq random;

        smoke = new();
        pull = new();
        push = new();
        random = new();

        for (int i = 0; i < NUM_FRAMES; i++) begin
            randcase
                10 : seq = smoke;
                10 : seq = pull;
                10 : seq = push;
                70 : seq = random;
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
            pin_agent.run();
            tx_agent.run();
            rx_agent.run();
        join_none

        driver.run();
        do @(posedge vif.clk); while (scoreboard_mailbox.num() != 0);
        repeat (5) @(posedge vif.clk);
        $display("\nPassed: %d\nFailed: %d\n", scoreboard.passed, scoreboard.failed);

        if (scoreboard.failed > 0) begin
            $fatal(1, "Fail.");
        end else if (scoreboard.passed == 0 && scoreboard.failed == 0) begin
            $fatal(1, "No checks performed.");
        end else if (scoreboard.stalled) begin
            $fatal(1, "An instruction has stalled for the duration of the test.");
        end else begin
            $display("Pass.");
        end
        $finish(0);
    endtask
endclass