# 실험 전 레포트: PWM 기반 LED 밝기 제어

작성일 2026-09-25.

## 1. 목적과 핵심 파라미터 계산

### 실험 목적
온보드 50 MHz 메인 클록을 기반으로 푸시버튼을 누를 때마다 펄스 폭 변조(PWM)의 듀티비(Duty Cycle)를 10%씩 가감 순환시켜 8개의 LED 밝기를 10단계(0%~100%)로 제어하는 동기식 디지털 회로를 설계한다. 외부 비동기 스위치 입력에 대해 2단 동기화기 및 20 ms 안정화 디바운스 회로를 적용하여 채터링 현상을 제거하고, 1클록 폭의 펄스를 통해 신뢰성 높은 단일 상태 전이를 달성한다.

### 핵심 파라미터 계산
1. **PWM 주기 카운트 (`PERIOD_CYCLES`)**:
   - 입력 주 클록 주파수 $f_{\mathrm{clk}} = 50\text{ MHz} = 50,000,000\text{ Hz}$
   - PWM 목표 스위칭 주파수 $f_{\mathrm{pwm}} = 1\text{ kHz} = 1,000\text{ Hz}$ (LED 깜빡임이 눈에 인지되지 않는 주파수)
   - 1주기당 클록 수:
     $$\text{PERIOD\_CYCLES} = \frac{f_{\mathrm{clk}}}{f_{\mathrm{pwm}}} = \frac{50,000,000}{1,000} = 50,000\text{ cycles}$$

   - 카운터 레지스터 비트 폭:
     $$\text{COUNT\_WIDTH} = \lceil\log_2(50,000)\rceil = 16\text{ bits}$$

2. **버튼 디바운스 안정화 카운트 (`DEBOUNCE_CYCLES`)**:
   - 스위치 접점 채터링 해소를 위한 목표 안정 시간 $T_{\mathrm{stable}} = 20\text{ ms} = 0.02\text{ s}$
   - 필요 클록 주기 수:
     $$\text{DEBOUNCE\_CYCLES} = 50,000,000 \times 0.02 = 1,000,000\text{ cycles}$$

   - 디바운스 카운터 비트 폭:
     $$\text{COUNT\_WIDTH} = \lceil\log_2(1,000,000)\rceil = 20\text{ bits}$$


3. **단계별 임계값 (`threshold`) 및 듀티비**:
   - 10단계(`LEVELS = 10`) 기준, $\text{threshold} = \frac{\text{PERIOD\_CYCLES} \times \text{level}}{\text{LEVELS}} = 5,000 \times \text{level}$
   - level=0: threshold=0 (High 클록 0개, 듀티 0%, 완전 소등)
   - level=3: threshold=15,000 (High 클록 15,000개, 듀티 30%)
   - level=10: threshold=50,000 (상시 High, 듀티 100%, 최대 밝기)

---

## 2. 파일 구성과 역할

| 경로 | 파일명 | 역할 및 설명 |
|---|---|---|
| `src/` | `button_onepulse.v` | 2단 동기화(ASYNC_REG)로 메타스테이블 방지 및 20 ms 디바운스 후 1클록 펄스 생성 |
| `src/` | `pwm_channel.v` | PERIOD_CYCLES 카운터와 임계값을 비교하여 듀티비에 따른 사각파 출력 |
| `src/` | `lab3_led_pwm.v` | 설계 최상위(Design Top). 버튼 입력 시 level 카운팅 및 8개 LED에 동일 PWM 분배 |
| `sim/` | `tb_led_pwm.sv` | 시뮬레이션 최상위(Simulation Top). 축소된 파라미터로 4대 경계 구간을 자기 검증 |
| `constraints/` | `lab3_led_pwm.xdc` | Spartan-7 B6(50MHz 클록), K4(리셋), N8(버튼), LED 8개 핀 매핑 및 20ns 타이밍 제약 |
| 루트 | `simulation.json` | VS Code Icarus Verilog 구동을 위한 컴파일 소스 및 최상위 모듈 지정 |

---

## 3. 테스트벤치 자극과 기대 결과

시뮬레이션 환경에서는 시간 단축을 위해 `CLK_HZ=1000`, `PWM_HZ=100`, `LEVELS=10`, `DEBOUNCE_CYCLES=2`로 축소 인가하며, 1주기(10클록) 동안 `led[0]`의 High 클록 수를 검사한다.

| 검사 순서 | 인가 자극 | 설정 level | 1주기 내 High 클록 기대값 (`high_count`) | 판정 기준 및 검증 의미 |
|:---:|---|:---:|:---:|---|
| Check 1 | 리셋 직후 초기 상태 | 0 | 0 | 듀티 0% 소등 확인 |
| Check 2 | 버튼 3회 연속 누름 | 3 | 3 | 듀티 30% 중간 밝기 확인 |
| Check 3 | 추가 버튼 7회 누름 | 10 | 10 | 듀티 100% 최대 밝기 확인 |
| Check 4 | 추가 버튼 1회 누름 | 0 | 0 | 100% 다음 0% 순환(Wrap-around) 확인 |

---

## 4. 시뮬레이션 결과 및 수정 실험

### 정상 시뮬레이션 확인
- **[종료 로그](../../evidence/01/vscode/simulation.txt)**: `LAB3_LED_PWM_PASS checks=4`, 종료 시각 `3831000 ps (3831 ns)`
- **[파형 분석](../../evidence/01/vscode/wave.png)**:
  - `level=0` 구간: `led[7:0]`이 상시 0을 유지.
  - `level=3` 구간: 1주기 10클록 중 3클록 동안 `led=8'hFF`, 나머지 7클록 동안 `led=8'h00` 표출.
  - `level=10` 구간: 전체 주기에 걸쳐 `led=8'hFF`로 High 유지.
  - 10에서 버튼 인가 시 오버플로 없이 즉시 `level=0`으로 복귀하여 0%로 초기화됨을 확인.

### 수정 실험 (오류 주입 및 복구)
`LEVELS` 파라미터를 10에서 5로 고의 수정하여 단계별 High 펄스 폭 변화 및 테스트벤치 검출 신뢰성을 점검한다.

| 실험 단계 | 설정 내용 | 기대 동작 | 실제 실행 결과 | 비고 |
|---|---|---|---|---|
| 정상 실행 | `LEVELS = 10` | 버튼 3회 시 30% (High 3클록) | `LAB3_LED_PWM_PASS checks=4` (3831 ns 종료) | 정상 통과 |
| 고장 주입 | `LEVELS = 5` 로 변경 | 1단계당 20%씩 증가하여 3회 시 60% 출력 | `level=3 high=6` 불일치 감지, `$fatal` 강제 중단 | 테스트벤치 검증 유효성 확인 |
| 원복 복구 | `LEVELS = 10` 복원 | 1단계당 10% 단위 증감 복구 | `LAB3_LED_PWM_PASS checks=4` 복구 | 정상 확인 |

---

## 5. 보드 실험 계획 및 관찰 항목

### 하드웨어 환경 및 핀 매핑
- **타깃 FPGA**: Spartan-7 `xc7s75fgga484-1`
- **클록원**: 온보드 50 MHz 오실레이터 (B6 핀)
- **입출력 핀**: 리셋 K4, 밝기 버튼 N8, LED[7:0] (N5, M1, M3, M7, N7, M2, M4, L4)

### 보드 관찰 절차
1. Vivado Hardware Manager로 비트스트림(`lab3_led_pwm.bit`) 다운로드 후 K4 버튼으로 리셋 초기화를 수행하여 8개 LED가 모두 소등(듀티 0%)되는지 확인한다.
2. N8 푸시버튼을 누를 때마다 8개 LED의 밝기가 10% 단위로 단계적으로 밝아지는지 육안으로 관찰한다.
3. 10번째 누름에서 최대 밝기(듀티 100%)에 도달하고, 11번째 누름 시 다시 완전히 꺼진 상태(듀티 0%)로 순환하는지 계측한다.
4. 버튼을 길게 누르고 있어도 20 ms 디바운스 로직에 의해 밝기가 연속으로 바뀌지 않고 1단계만 반영되는지 확인한다.