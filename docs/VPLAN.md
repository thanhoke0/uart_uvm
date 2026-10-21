# Verification plan – UART TX

## Đặc tả cần giữ

Dữ liệu nhận tại cạnh lên khi valid và ready cùng bằng 1. ready bằng phủ định busy. Dữ liệu/cấu hình chỉ chốt tại handshake; không cập nhật theo input trong lúc truyền. TX idle và reset là 1. Reset có ưu tiên cao nhất; một khung bị reset không tạo done hoàn tất. Nếu valid vẫn được giữ khi bộ truyền trở lại ready, một yêu cầu mới có thể được nhận tại cạnh lên kế tiếp.

| ID | Nội dung | Kích thích | Kiểm tra | Nơi thực hiện |
|---|---|---|---|---|
| TX01 | Reset ban đầu | Giữ rst_n=0 | TX=1, busy=0, ready=1, done=0 | RTL |
| TX02 | Toàn bộ dữ liệu | 0x00–0xFF | Giải mã LSB trước, so sánh payload | RTL + UVM |
| TX03 | Không parity | mode=0 | 8 dữ liệu rồi stop | RTL + UVM |
| TX04 | Even parity | mode=1 | parity = XOR dữ liệu | RTL + UVM |
| TX05 | Odd parity | mode=2 | parity = NOT XOR dữ liệu | RTL + UVM |
| TX06 | Một stop | two_stop=0 | Stop cao đủ một bit | RTL + UVM |
| TX07 | Hai stop | two_stop=1 | Stop cao đủ hai bit | RTL + UVM |
| TX08 | Độ dài bit/khung | divisor=2,8,16 | So từng chu kỳ; kiểm tra cạnh done | RTL; UVM lấy mẫu giữa bit |
| TX09 | Bỏ qua yêu cầu khi bận | Pulse valid trong khung | Không khởi động lại hoặc thêm khung | RTL |
| TX10 | Chốt cấu hình | Đổi input khi busy | Khung đang truyền giữ cấu hình gốc | RTL |
| TX11 | Reset giữa khung | Reset lệch cạnh clock | TX về idle ngay, hủy khung | RTL |
| TX12 | Phục hồi sau reset | Gửi 0x96 sau reset | Khung mới đúng | RTL |
| TX13 | Khoảng nghỉ ngẫu nhiên | gap=0–7 | Không mất/thừa giao dịch | UVM |
| TX14 | Mode dự phòng | mode=3 | Như không parity | RTL |
| TX15 | Divisor không hợp lệ | divisor=0,1 | Kẹp về 2 | RTL |
| TX16 | done một chu kỳ | Kết thúc mỗi khung | done không giữ nhiều chu kỳ | RTL |
| TX17 | Giao dịch đủ số lượng | Kết thúc sequence | 4608+N_RANDOM khung so sánh | UVM |

## Coverage và tiêu chí đóng kiểm chứng

- Payload: 256 bins; parity: 3 bins; stop: 2 bins; divisor: 3 bins.
- Cross payload × parity × stop: 1536 tổ hợp; cross parity × stop × divisor: 18 tổ hợp.
- Framing lỗi là illegal bin; scoreboard đồng thời báo UVM_ERROR nếu khung sai.
- Điều kiện pass UVM: không UVM_ERROR/UVM_FATAL, không timeout, đủ số khung và FIFO không còn giao dịch.
- Mục tiêu functional coverage là 100% bins hợp lệ đã khai báo; cần chạy simulator để xác nhận.
- Code coverage Questa là số liệu bổ sung. Không dùng code coverage hoặc functional coverage một mình để khẳng định DUT hoàn toàn đúng.

## Giới hạn và hướng mở rộng

Chưa có UVM test cho reset giữa khung, giữ valid liên tục, divider lớn nhất 65535, hoặc coverage cho busy rejection. Bài RTL có reset giữa khung và busy rejection nhưng chưa có chiến dịch reset trên mọi vị trí bit. Chưa kiểm tra receiver, lỗi đường truyền tới receiver, CDC, metastability, FIFO hay APB vì các khối này không nằm trong DUT hiện tại.

Khi mở rộng, nên thêm reset-aware monitor/scoreboard, test held-valid, bins vị trí reset và kiểm tra dải divisor rộng hơn trước khi tích hợp RX/APB. Không gọi testbench hiện tại là verification closure của toàn bộ UART.
