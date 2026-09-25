`timescale 1ns/1ps

module tb_led_pwm;
  reg clk_50mhz = 0, rst_p = 1, button = 0;
  wire [7:0] led;
  integer checks = 0, high_count, i;

  // 50 MHz 클록 생성 (#10 반전 = 20 ns 주기)
  always #10 clk_50mhz = ~clk_50mhz;

  // 시뮬레이션용 빠른 파라미터 축소 설정
  lab3_led_pwm #(
    .CLK_HZ(1000),
    .PWM_HZ(100),
    .LEVELS(10),
    .DEBOUNCE_CYCLES(2)
  ) dut (
    .clk_50mhz(clk_50mhz),
    .rst_p(rst_p),
    .button(button),
    .led(led)
  );

  // 버튼 누름 자극 태스크
  task press_button;
    begin
      button = 1; repeat(6) @(posedge clk_50mhz);
      button = 0; repeat(6) @(posedge clk_50mhz);
    end
  endtask

  // 1주기(10클록) 동안 High 클록 수를 검사하는 태스크
  task expect_level(input integer expected);
    begin
      wait(dut.u_pwm.count == 0);
      high_count = 0;
      for(i=0; i<10; i=i+1) begin
        @(posedge clk_50mhz);
        #1;
        if(led[0]) high_count = high_count + 1;
      end
      if(high_count !== expected)
        $fatal(1, "level=%0d high=%0d", expected, high_count);
      checks = checks + 1;
    end
  endtask

  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_led_pwm);
    repeat(3) @(posedge clk_50mhz);
    rst_p = 0;

    expect_level(0);                        // 0% 검사
    repeat(3) press_button(); expect_level(3); // 30% 검사
    repeat(7) press_button(); expect_level(10); // 100% 검사
    press_button(); expect_level(0);        // 100% 다음 0% 순환 검사

    $display("LAB3_LED_PWM_PASS checks=%0d", checks);
    $finish;
  end

  initial begin
    #20000;
    $fatal(1, "timeout");
  end

endmodule