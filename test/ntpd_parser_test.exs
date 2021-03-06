defmodule NtpdParserTest do
  use ExUnit.Case

  alias Nerves.Time.NtpdParser

  test "decodes addresses" do
    assert NtpdParser.parse("ntpd: bad address '0.pool.ntp.org'") ==
             {:bad_address, %{server: "0.pool.ntp.org"}}

    assert NtpdParser.parse("ntpd: '1.pool.ntp.org' is 195.78.244.50") ==
             {:address, %{server: "1.pool.ntp.org", address: "195.78.244.50"}}
  end

  test "decodes requests" do
    assert NtpdParser.parse("ntpd: sending query to 195.78.244.50") ==
             {:query, %{address: "195.78.244.50"}}
  end

  test "decodes responses" do
    {:reply, result} =
      NtpdParser.parse(
        "ntpd: reply from 35.237.173.121: offset:-0.000109 delay:0.018289 status:0x24 strat:3 refid:0xfea9fea9 rootdelay:0.000916 reach:0x03"
      )

    assert result.address == "35.237.173.121"
    assert result.offset == -0.000109
    assert result.delay == 0.018289
    assert result.status == 0x24
    assert result.stratum == 3
    assert result.refid == 0xFEA9FEA9
    assert result.rootdelay == 0.000916
    assert result.reach == 0x03
  end

  test "decodes timeout" do
    {:timeout, result} =
      NtpdParser.parse(
        "ntpd: timed out waiting for 35.237.173.121, reach 0x0a, next query in 33s"
      )

    assert result.address == "35.237.173.121"
    assert result.reach == 0x0A
    assert result.next_query == 33
  end

  test "decodes ntpscript stratum report" do
    {:stratum, result} = NtpdParser.parse("ntpd_script: stratum,0,0.190975,3,1")

    assert result.freq_drift_ppm == 0
    assert result.offset == 0.190975
    assert result.stratum == 3
    assert result.poll_interval == 1
  end

  test "decodes ntpscript unsync report" do
    {:unsync, result} = NtpdParser.parse("ntpd_script: unsync,-303,0.0000,16,64")

    assert result.freq_drift_ppm == -303
    assert result.offset == 0
    assert result.stratum == 16
    assert result.poll_interval == 64
  end

  test "decodes ntpscript step report" do
    {:step, result} = NtpdParser.parse("ntpd_script: step,0,0.190975,3,1")

    assert result.freq_drift_ppm == 0
    assert result.offset == 0.190975
    assert result.stratum == 3
    assert result.poll_interval == 1
  end

  test "decodes ntpscript periodic report" do
    {:periodic, result} = NtpdParser.parse("ntpd_script: periodic,-257,0.163099,3,32")

    assert result.freq_drift_ppm == -257
    assert result.offset == 0.163099
    assert result.stratum == 3
    assert result.poll_interval == 32

    # Network totally down
    {:periodic, result} = NtpdParser.parse("ntpd_script: periodic,0,0.000000,16,1")
    assert result.freq_drift_ppm == 0
    assert result.offset == 0
    assert result.stratum == 16
    assert result.poll_interval == 1
  end

  test "ignores junk" do
    assert NtpdParser.parse("\n") == {:ignored, "\n"}
    assert NtpdParser.parse("something") == {:ignored, "something"}
    assert NtpdParser.parse("ntpd: new stuff") == {:ignored, "ntpd: new stuff"}

    assert NtpdParser.parse("ntpd: executing './priv/ntpd_script stratum'") ==
             {:ignored, "ntpd: executing './priv/ntpd_script stratum'"}
  end
end
