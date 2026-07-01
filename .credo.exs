%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "config/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/native/"]
      },
      strict: true,
      parse_timeout: 5000,
      color: true
    }
  ]
}
