library verilog;
use verilog.vl_types.all;
entity ads7953_model is
    generic(
        FIRST_BASE      : vl_logic_vector(11 downto 0) := (Hi0, Hi0, Hi0, Hi1, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0)
    );
    port(
        cs_n            : in     vl_logic;
        sclk            : in     vl_logic;
        sdi             : in     vl_logic;
        sdo             : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of FIRST_BASE : constant is 2;
end ads7953_model;
