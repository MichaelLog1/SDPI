class sm_pin_agent;
    virtual sm_core_if vif;
    int hold_times [NUM_PINS]; // a reload of N gives a hold of N+! cycles
    rand int reload;
    logic [NUM_PINS-1:0] pin_mask = '1;

    function new(virtual sm_core_if _vif);
        vif = _vif;
    endfunction

    function void set_mask(logic [NUM_PINS-1:0] _pin_mask);
        pin_mask = _pin_mask;
    endfunction

    task run();
        logic [NUM_PINS-1:0] uio_in = '0;

        for (int i = 0; i < NUM_PINS; i++) begin
            assert(randomize(reload));
            hold_times[i] = reload;
        end

        forever begin
            @(vif.driver_cb);
            // determine uio_in
            for (int i = 0; i < NUM_PINS; i++) begin
                if (hold_times[i] == 0) begin
                    // flip uio_in bit
                    uio_in[i] = ~uio_in[i];

                    // randomize hold length
                    assert(randomize(reload));
                    hold_times[i] = reload;
                end else begin
                    // decrement hold count
                    hold_times[i]--;
                end
            end
            
            // drive uio_in
            vif.driver_cb.uio_in <= uio_in & pin_mask;
        end
    endtask

    // constraints
    constraint c_reload {
        reload dist {
            0 :/ 50,
            [1:100] :/ 50
        };
    }
endclass
