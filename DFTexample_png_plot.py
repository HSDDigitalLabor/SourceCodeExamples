import numpy as np
import matplotlib
# Verhindert das Öffnen von GUI-Fenstern
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def getSineSignal(amps, freqs, t):
    x = np.zeros_like(t)
    for a, f in zip(amps, freqs):
        x += a * np.sin(2 * np.pi * f * t)

    return x


def computeDFT(x):
    global MW_n

    N = x.size
    n = np.arange(N)  # row vector
    k = n.reshape((N, 1))  # column vector

    MW_n = np.exp(-2j * np.pi * k * n / N)
    X_k = np.zeros_like(k, dtype=np.complex128)
    for col in n:
        for row in n:
            X_k[col] += MW_n[col, row] * x[row]
    return X_k


def vDFT(x):
    N = x.size
    n = np.arange(N)
    k = n.reshape((N, 1))

    e = np.exp(-2j * np.pi * k * n / N)
    X_k = np.dot(e, k)

    return X_k


def plot_signal(t, x, numeric=True):
    plt.figure(figsize=(8, 6))
    if numeric:
        n = np.arange(x.size)
        plt.plot(n, x, "r")
        plt.xlabel("n (samples)")
    else:
        plt.plot(t, x, "r")
        plt.xlabel("t (s)")
    plt.ylabel("s")
    plt.grid(True)
    plt.savefig("signal.png")
    plt.close()


def plot_dft(X_k, freq, zoom=False):
    plt.figure(figsize=(8, 6))
    if not zoom:
        plt.stem(freq, abs(X_k), "b", markerfmt=" ", basefmt="-b")
    else:
        plt.stem(freq, abs(X_k), "b", markerfmt="bs", basefmt="-b")
        plt.xlim(0, 12)
    plt.xlabel("Freq (Hz)")
    plt.ylabel("Amplitude |S(f)|")
    plt.grid(True)
    plt.savefig("dft.png")
    plt.close()


def dft_example(sampling_rate, length=1, freq_offset=0):
    global t, x, X_k, freq, X_k_oneside, f_oneside

    T_s = 1 / sampling_rate

    t_start = 0
    t_end = length

    t = np.arange(t_start, t_end, T_s)

    # compute signal
    amps = np.array([9, 10, 2.3])
    freqs = np.array([2, 1, 10 + freq_offset])
    x = getSineSignal(amps, freqs, t)

    # compute DFT
    X_k = computeDFT(x)
    N = X_k.size
    n = np.arange(N)
    T = N / sampling_rate
    freq = n / T

    # limit DFT to one side
    n_oneside = N // 2
    f_oneside = freq[:n_oneside]
    X_k_oneside = X_k[:n_oneside] / n_oneside


# Beispielaufruf (plot_signal und plot_dft jeweils nur einmal aufrufen,
# da sonst die jeweilige PNG-Datei überschrieben wird):
# dft_example(sampling_rate=64, length=1, freq_offset=0)
# plot_signal(t, x)
# plot_dft(X_k_oneside, f_oneside, zoom=True)
