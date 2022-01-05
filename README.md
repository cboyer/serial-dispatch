# serial-dispatch

Elixir/OTP application to read data from serial device (initially written for OBD2 data) and stream it to file and TCP clients. This application relies on [Circuits.UART library](https://hexdocs.pm/circuits_uart/readme.html).


## Clone this repository:
```Bash
git clone https://github.com/cboyer/serial-dispatch
```

Configure your device in `config/config.exs` with `device:`.
You can list all connected devices with `Circuits.UART.enumerate` once compiled and change it later.

```Elixir
@device %{description: "Arduino Due", manufacturer: "Arduino LLC", product_id: 62, vendor_id: 9025}
```

## Compile:
```Bash
cd serial-dispatch
mix deps.get
mix compile
```

## Run:
```Bash
iex -S mix
```
