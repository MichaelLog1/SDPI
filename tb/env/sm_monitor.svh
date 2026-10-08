class sm_monitor;
    mailbox #(sm_obs) scoreboard_mailbox;
    virtual sm_core_if vif;

    function new(virtual sm_core_if _vif, mailbox #(sm_obs) mb);
        scoreboard_mailbox = mb;
        vif = _vif;
    endfunction

    task run();
        sm_obs item;
        forever begin
            @(vif.monitor_cb);
            item = new;
            item.sample(vif);
            scoreboard_mailbox.put(item);
        end
    endtask
endclass
