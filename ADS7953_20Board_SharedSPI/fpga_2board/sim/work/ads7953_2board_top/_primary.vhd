library verilog;
use verilog.vl_types.all;
entity ads7953_2board_top is
    generic(
        CLK_HZ          : integer := 50000000;
        UART_BAUD       : integer := 115200;
        ADC_SCLK_HZ     : integer := 1000000
    );
    port(
        clk             : in     vl_logic;
        rst_n           : in     vl_logic;
        uart_rxd        : in     vl_logic;
        uart_txd        : out    vl_logic;
        adc_cs_n        : out    vl_logic_vector(1 downto 0);
        adc_sclk        : out    vl_logic;
        adc_sdi         : out    vl_logic;
        adc_sdo         : in     vl_logic;
        ready           : out    vl_logic;
        busy            : out    vl_logic;
        packet_busy     : out    vl_logic;
        sample_valid    : out    vl_logic;
        sample_board    : out    vl_logic;
        sample_channel  : out    vl_logic_vector(3 downto 0);
        sample_code     : out    vl_logic_vector(11 downto 0)
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of CLK_HZ : constant is 2;
    attribute mti_svvh_generic_type of UART_BAUD : constant is 2;
    attribute mti_svvh_generic_type of ADC_SCLK_HZ : constant is 2;
end ads7953_2board_top;
