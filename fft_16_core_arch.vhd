architecture rtl of fft16_core is
    subtype int20_t is signed(19 downto 0);
    type complex_array_16 is array (0 to 15) of signed(15 downto 0);
    type complex_array_20 is array (0 to 15) of int20_t;

    signal buf_re, buf_im : complex_array_16 := (others => (others => '0'));
    signal res_re, res_im : complex_array_16 := (others => (others => '0'));

    signal sample_cnt : unsigned(3 downto 0) := (others => '0');
    signal out_cnt    : unsigned(3 downto 0) := (others => '0');
    signal busy_out   : std_logic := '0';

    -- Twiddle-Konstanten in Q14
    constant C_COS_PI8 : signed(15 downto 0) := to_signed(15137, 16); -- cos(22.5°)
    constant C_SIN_PI8 : signed(15 downto 0) := to_signed(6270, 16);  -- sin(22.5°)
    constant C_W8      : signed(15 downto 0) := to_signed(11585, 16); -- cos(45.0°)

    procedure cmult_q14(
        ar, ai : in  int20_t;
        wr, wi : in  signed(15 downto 0);
        pr, pi : out int20_t
    ) is
        variable p_rr, p_ii, p_ri, p_ir : signed(35 downto 0);
        variable sum_r, sum_i           : signed(35 downto 0);
    begin
        p_rr  := ar * wr;
        p_ii  := ai * wi;
        p_ri  := ar * wi;
        p_ir  := ai * wr;
        sum_r := (p_rr - p_ii) + to_signed(8192, 36);
        sum_i := (p_ri + p_ir) + to_signed(8192, 36);
        pr    := resize(shift_right(sum_r, 14), 20);
        pi    := resize(shift_right(sum_i, 14), 20);
    end procedure;

begin

    process(clk)
        variable s0_r, s0_i : complex_array_20;
        variable s1_r, s1_i : complex_array_20;
        variable s2_r, s2_i : complex_array_20;
        variable s3_r, s3_i : complex_array_20;
        variable s4_r, s4_i : complex_array_20;
        variable t_r, t_i   : int20_t;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                sample_cnt <= (others => '0');
                out_cnt    <= (others => '0');
                out_valid  <= '0';
                busy_out   <= '0';
            else
                out_valid <= '0';

                -- 1. Eingangs-Sampling (nur wenn nicht gerade ausgegeben wird)
                if in_valid = '1' and busy_out = '0' then
                    buf_re(to_integer(sample_cnt)) <= in_re;
                    buf_im(to_integer(sample_cnt)) <= in_im;

                    if sample_cnt = 15 then
                        sample_cnt <= (others => '0');
                        busy_out   <= '1';
                        out_cnt    <= (others => '0');

                        -- Bit-Reversal Indexierung + 20-Bit Erweiterung
                        s0_r(0)  := resize(buf_re(0), 20);  s0_i(0)  := resize(buf_im(0), 20);
                        s0_r(1)  := resize(buf_re(8), 20);  s0_i(1)  := resize(buf_im(8), 20);
                        s0_r(2)  := resize(buf_re(4), 20);  s0_i(2)  := resize(buf_im(4), 20);
                        s0_r(3)  := resize(buf_re(12), 20); s0_i(3)  := resize(buf_im(12), 20);
                        s0_r(4)  := resize(buf_re(2), 20);  s0_i(4)  := resize(buf_im(2), 20);
                        s0_r(5)  := resize(buf_re(10), 20); s0_i(5)  := resize(buf_im(10), 20);
                        s0_r(6)  := resize(buf_re(6), 20);  s0_i(6)  := resize(buf_im(6), 20);
                        s0_r(7)  := resize(buf_re(14), 20); s0_i(7)  := resize(buf_im(14), 20);
                        s0_r(8)  := resize(buf_re(1), 20);  s0_i(8)  := resize(buf_im(1), 20);
                        s0_r(9)  := resize(buf_re(9), 20);  s0_i(9)  := resize(buf_im(9), 20);
                        s0_r(10) := resize(buf_re(5), 20);  s0_i(10) := resize(buf_im(5), 20);
                        s0_r(11) := resize(buf_re(13), 20); s0_i(11) := resize(buf_im(13), 20);
                        s0_r(12) := resize(buf_re(3), 20);  s0_i(12) := resize(buf_im(3), 20);
                        s0_r(13) := resize(buf_re(11), 20); s0_i(13) := resize(buf_im(11), 20);
                        s0_r(14) := resize(buf_re(7), 20);  s0_i(14) := resize(buf_im(7), 20);
                        s0_r(15) := resize(in_re, 20);      s0_i(15) := resize(in_im, 20);

                        -- Stufe 1
                        for k in 0 to 7 loop
                            s1_r(2*k)   := s0_r(2*k) + s0_r(2*k+1);
                            s1_i(2*k)   := s0_i(2*k) + s0_i(2*k+1);
                            s1_r(2*k+1) := s0_r(2*k) - s0_r(2*k+1);
                            s1_i(2*k+1) := s0_i(2*k) - s0_i(2*k+1);
                        end loop;

                        -- Stufe 2
                        for k in 0 to 3 loop
                            s2_r(4*k)   := s1_r(4*k) + s1_r(4*k+2);
                            s2_i(4*k)   := s1_i(4*k) + s1_i(4*k+2);
                            s2_r(4*k+2) := s1_r(4*k) - s1_r(4*k+2);
                            s2_i(4*k+2) := s1_i(4*k) - s1_i(4*k+2);

                            s2_r(4*k+1) := s1_r(4*k+1) + s1_i(4*k+3);
                            s2_i(4*k+1) := s1_i(4*k+1) - s1_r(4*k+3);
                            s2_r(4*k+3) := s1_r(4*k+1) - s1_i(4*k+3);
                            s2_i(4*k+3) := s1_i(4*k+1) + s1_r(4*k+3);
                        end loop;

                        -- Stufe 3
                        for k in 0 to 1 loop
                            s3_r(8*k+0) := s2_r(8*k+0) + s2_r(8*k+4);
                            s3_i(8*k+0) := s2_i(8*k+0) + s2_i(8*k+4);
                            s3_r(8*k+4) := s2_r(8*k+0) - s2_r(8*k+4);
                            s3_i(8*k+4) := s2_i(8*k+0) - s2_i(8*k+4);

                            cmult_q14(s2_r(8*k+5), s2_i(8*k+5), C_W8, -C_W8, t_r, t_i);
                            s3_r(8*k+1) := s2_r(8*k+1) + t_r;
                            s3_i(8*k+1) := s2_i(8*k+1) + t_i;
                            s3_r(8*k+5) := s2_r(8*k+1) - t_r;
                            s3_i(8*k+5) := s2_i(8*k+1) - t_i;

                            s3_r(8*k+2) := s2_r(8*k+2) + s2_i(8*k+6);
                            s3_i(8*k+2) := s2_i(8*k+2) - s2_r(8*k+6);
                            s3_r(8*k+6) := s2_r(8*k+2) - s2_i(8*k+6);
                            s3_i(8*k+6) := s2_i(8*k+2) + s2_r(8*k+6);

                            cmult_q14(s2_r(8*k+7), s2_i(8*k+7), -C_W8, -C_W8, t_r, t_i);
                            s3_r(8*k+3) := s2_r(8*k+3) + t_r;
                            s3_i(8*k+3) := s2_i(8*k+3) + t_i;
                            s3_r(8*k+7) := s2_r(8*k+3) - t_r;
                            s3_i(8*k+7) := s2_i(8*k+3) - t_i;
                        end loop;

                        -- Stufe 4
                        s4_r(0) := s3_r(0) + s3_r(8);
                        s4_i(0) := s3_i(0) + s3_i(8);
                        s4_r(8) := s3_r(0) - s3_r(8);
                        s4_i(8) := s3_i(0) - s3_i(8);

                        cmult_q14(s3_r(9), s3_i(9), C_COS_PI8, -C_SIN_PI8, t_r, t_i);
                        s4_r(1) := s3_r(1) + t_r;  s4_i(1) := s3_i(1) + t_i;
                        s4_r(9) := s3_r(1) - t_r;  s4_i(9) := s3_i(1) - t_i;

                        cmult_q14(s3_r(10), s3_i(10), C_W8, -C_W8, t_r, t_i);
                        s4_r(2)  := s3_r(2) + t_r; s4_i(2)  := s3_i(2) + t_i;
                        s4_r(10) := s3_r(2) - t_r; s4_i(10) := s3_i(2) - t_i;

                        cmult_q14(s3_r(11), s3_i(11), C_SIN_PI8, -C_COS_PI8, t_r, t_i);
                        s4_r(3)  := s3_r(3) + t_r; s4_i(3)  := s3_i(3) + t_i;
                        s4_r(11) := s3_r(3) - t_r; s4_i(11) := s3_i(3) - t_i;

                        s4_r(4)  := s3_r(4) + s3_i(12);
                        s4_i(4)  := s3_i(4) - s3_r(12);
                        s4_r(12) := s3_r(4) - s3_i(12);
                        s4_i(12) := s3_i(4) + s3_r(12);

                        cmult_q14(s3_r(13), s3_i(13), -C_SIN_PI8, -C_COS_PI8, t_r, t_i);
                        s4_r(5)  := s3_r(5) + t_r; s4_i(5)  := s3_i(5) + t_i;
                        s4_r(13) := s3_r(5) - t_r; s4_i(13) := s3_i(5) - t_i;

                        cmult_q14(s3_r(14), s3_i(14), -C_W8, -C_W8, t_r, t_i);
                        s4_r(6)  := s3_r(6) + t_r; s4_i(6)  := s3_i(6) + t_i;
                        s4_r(14) := s3_r(6) - t_r; s4_i(14) := s3_i(6) - t_i;

                        cmult_q14(s3_r(15), s3_i(15), -C_COS_PI8, -C_SIN_PI8, t_r, t_i);
                        s4_r(7)  := s3_r(7) + t_r; s4_i(7)  := s3_i(7) + t_i;
                        s4_r(15) := s3_r(7) - t_r; s4_i(15) := s3_i(7) - t_i;

                        -- Normierung / Skalierung auf 16 Bit
                        for k in 0 to 15 loop
                            res_re(k) <= resize(shift_right(s4_r(k) + to_signed(8, 20), 4), 16);
                            res_im(k) <= resize(shift_right(s4_i(k) + to_signed(8, 20), 4), 16);
                        end loop;
                    else
                        sample_cnt <= sample_cnt + 1;
                    end if;
                end if;

                -- 2. Serielle Ausgabe (gestartet exakt wenn busy_out = '1')
                if busy_out = '1' then
                    out_valid <= '1';
                    bin_idx   <= out_cnt;
                    out_re    <= res_re(to_integer(out_cnt));
                    out_im    <= res_im(to_integer(out_cnt));

                    if out_cnt = 15 then
                        busy_out <= '0';
                    else
                        out_cnt <= out_cnt + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture rtl;
