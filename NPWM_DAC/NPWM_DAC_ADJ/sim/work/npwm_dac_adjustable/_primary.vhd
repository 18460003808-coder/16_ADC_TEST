library verilog;
use verilog.vl_types.all;
entity npwm_dac_adjustable is
    port(
        sysclk          : in     vl_logic;
        rst_n           : in     vl_logic;
        trig            : in     vl_logic;
        rst_pwm_n       : in     vl_logic;
        period_count    : in     vl_logic_vector(12 downto 0);
        pwm_out         : out    vl_logic;
        pwm_duty        : out    vl_logic_vector(6 downto 0)
    );
end npwm_dac_adjustable;
