# Linux amdgpu Radeon VRAM Swapping Test

In theory all test results should/could have roughly similar speeds.
However in practice (Linux 6.1, open-source amdgpu driver) tests
5 and 6 have a lot worse performance especially when an eGPU enclosure
is used.

It seems that the Linux amdgpu driver:

1. Uses system memory (GTT) when VRAM is full (as expected)
2. Never moves objects allocated on GTT back to VRAM? Neither
when VRAM becomes available again, nor based on actual usage.
(unexpected)

---

```
GPU: Bus=0x07:00 DevId=0x73EF   8GB AMD Radeon RX 6650 XT (RADV NAVI23)
Detected VRAM size: 8192MB
```

### Starting 1st test: baseline, small ###
```
Running benchmark on one chunk of 1024MB of VRAM...
Result:
    VRAM: 13.50% 1100.93mb, GTT: 0.19% 28.68mb
    656 iteration. Passed  5.0058 seconds  written:  272.0GB 204.0GB/sec        checked:  544.0GB 148.1GB/sec
```

### Starting 2nd test: baseline, full ###
```
Running benchmark on all available VRAM...
Result:
    VRAM: 92.46% 7537.06mb, GTT: 0.19% 28.70mb
    114 iteration. Passed  5.0516 seconds  written:  340.8GB 243.7GB/sec        checked:  681.5GB 186.5GB/sec
```

### Starting 3rd test: Half clogged VRAM ###
```
Clogging VRAM with idle / SIGSTOP'ed processes,
allocating 4 chunks of size 1024MB:
... 1024MB allocated --- usage: VRAM: 13.50% 1100.93mb, GTT: 0.19% 28.68mb
... 2048MB allocated --- usage: VRAM: 26.08% 2125.96mb, GTT: 0.19% 28.71mb
... 3072MB allocated --- usage: VRAM: 38.65% 3151.00mb, GTT: 0.19% 28.75mb
... 4096MB allocated --- usage: VRAM: 51.23% 4176.04mb, GTT: 0.19% 28.78mb
Running benchmark on one chunk of 1024MB of VRAM...
Result:
    VRAM: 63.80% 5201.08mb, GTT: 0.19% 28.81mb
    672 iteration. Passed  5.0097 seconds  written:  280.0GB 214.1GB/sec        checked:  560.0GB 151.3GB/sec
```

### Starting 4th test: 3/4 clogged VRAM ###
```
Clogging VRAM with idle / SIGSTOP'ed processes,
allocating 6 chunks of size 1024MB:
... 1024MB allocated --- usage: VRAM: 13.50% 1100.93mb, GTT: 0.19% 28.68mb
... 2048MB allocated --- usage: VRAM: 26.08% 2125.96mb, GTT: 0.19% 28.71mb
... 3072MB allocated --- usage: VRAM: 38.65% 3151.00mb, GTT: 0.19% 28.75mb
... 4096MB allocated --- usage: VRAM: 51.23% 4176.04mb, GTT: 0.19% 28.78mb
... 5120MB allocated --- usage: VRAM: 63.80% 5201.08mb, GTT: 0.19% 28.81mb
... 6144MB allocated --- usage: VRAM: 76.37% 6226.12mb, GTT: 0.19% 28.84mb
Running benchmark on one chunk of 1024MB of VRAM...
Result:
    VRAM: 88.90% 7247.16mb, GTT: 0.17% 26.87mb
    664 iteration. Passed  5.0077 seconds  written:  276.0GB 212.3GB/sec        checked:  552.0GB 148.9GB/sec
```

### Starting 5th test: Fully clogged VRAM ###
```
Clogging VRAM with idle / SIGSTOP'ed processes,
allocating 10 chunks of size 1024MB:
... 1024MB allocated --- usage: VRAM: 13.46% 1096.93mb, GTT: 0.17% 26.68mb
... 2048MB allocated --- usage: VRAM: 26.03% 2121.96mb, GTT: 0.17% 26.71mb
... 3072MB allocated --- usage: VRAM: 38.60% 3147.00mb, GTT: 0.17% 26.75mb
... 4096MB allocated --- usage: VRAM: 51.18% 4172.04mb, GTT: 0.17% 26.78mb
... 5120MB allocated --- usage: VRAM: 63.75% 5197.08mb, GTT: 0.17% 26.81mb
... 6144MB allocated --- usage: VRAM: 76.33% 6222.12mb, GTT: 0.17% 26.84mb
... 7168MB allocated --- usage: VRAM: 88.90% 7247.16mb, GTT: 0.17% 26.87mb
... 8192MB allocated --- usage: VRAM: 88.91% 7248.20mb, GTT: 6.82% 1050.90mb
... 9216MB allocated --- usage: VRAM: 88.93% 7249.24mb, GTT: 13.47% 2074.93mb
... 10240MB allocated --- usage: VRAM: 88.94% 7250.28mb, GTT: 20.12% 3098.96mb
Running benchmark on one chunk of 1024MB of VRAM...
Result:
    VRAM: 88.95% 7251.32mb, GTT: 26.76% 4123.00mb
    12 iteration. Passed  5.4739 seconds  written:    4.5GB   2.6GB/sec        checked:    9.0GB   2.4GB/sec
```

### Starting 6th test: Temporarily fully clogged VRAM ###
```
Clogging VRAM with idle / SIGSTOP'ed processes,
allocating 10 chunks of size 1024MB:
... 1024MB allocated --- usage: VRAM: 13.46% 1096.93mb, GTT: 0.17% 26.68mb
... 2048MB allocated --- usage: VRAM: 26.03% 2121.96mb, GTT: 0.17% 26.71mb
... 3072MB allocated --- usage: VRAM: 38.60% 3147.00mb, GTT: 0.17% 26.75mb
... 4096MB allocated --- usage: VRAM: 51.18% 4172.04mb, GTT: 0.17% 26.78mb
... 5120MB allocated --- usage: VRAM: 63.75% 5197.08mb, GTT: 0.17% 26.81mb
... 6144MB allocated --- usage: VRAM: 76.33% 6222.12mb, GTT: 0.17% 26.84mb
... 7168MB allocated --- usage: VRAM: 88.90% 7247.16mb, GTT: 0.17% 26.87mb
... 8192MB allocated --- usage: VRAM: 88.91% 7248.20mb, GTT: 6.82% 1050.90mb
... 9216MB allocated --- usage: VRAM: 88.93% 7249.24mb, GTT: 13.47% 2074.93mb
... 10240MB allocated --- usage: VRAM: 88.94% 7250.28mb, GTT: 20.12% 3098.96mb
Starting benchmark process stopped
Killing clogging processes
Continuing benchmark process
Running benchmark on one chunk of 1024MB of VRAM...
Result:
    VRAM: 0.89% 72.93mb, GTT: 6.82% 1050.68mb
    64 iteration. Passed 30.2922 seconds  written:   26.0GB   2.7GB/sec        checked:   52.0GB   2.5GB/sec

End of benchmarking, exiting
```
