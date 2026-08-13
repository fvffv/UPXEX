using System.Diagnostics;
using System.Text;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Platform.Storage;
using Avalonia.VisualTree;

namespace UpxGui;

public partial class MainWindow : Window
{
    private const int StartupTimeoutMilliseconds = 15_000;

    private readonly string _upxPath;
    private UiLanguage _language = UiLanguage.Chinese;
    private string? _inputPath;
    private string? _unpackInputPath;

    public MainWindow()
    {
        InitializeComponent();
        _upxPath = FindUpxExecutable();

        // XAML creates named controls in declaration order. Subscribe only
        // after InitializeComponent, so selection cannot access null controls.
        AlgorithmBox.SelectionChanged += Algorithm_SelectionChanged;
        LevelBox.SelectionChanged += Level_SelectionChanged;
        LanguageBox.SelectionChanged += Language_SelectionChanged;
        AlgorithmBox.SelectedIndex = 0;
        LanguageBox.SelectedIndex = 1;
        RoundsBox.SelectedIndex = 1;
        ApplyLanguage();

        AppendLog(LogTextBox, File.Exists(_upxPath)
            ? $"UPX: {_upxPath}"
            : T("未找到 upx.exe。请将它放在程序目录或工作区内。", "upx.exe was not found. Put it next to this app or inside the workspace."));
    }

    private static string FindUpxExecutable()
    {
        var executableName = OperatingSystem.IsWindows() ? "upx.exe" : "upx";
        var candidates = new[]
        {
            Path.Combine(AppContext.BaseDirectory, executableName),
            Path.Combine(AppContext.BaseDirectory, "upx.exe"),
            Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "build-nextgenmisa77", "upx.exe")),
            Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "build-nextgenmisa77", "upx.exe")),
            Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "build-nextgenmisa77", "upx.exe")),
        };

        return candidates.FirstOrDefault(File.Exists) ?? candidates[0];
    }

    private void ApplyLanguage()
    {
        Title = "UPXEx GUI";
        AppSubtitleText.Text = T("面向启动速度的 UPX 压缩工具", "UPX compression tool for startup speed");
        FastStartBadgeText.Text = "misa77 · Fast Start";
        PackTabHeaderText.Text = T("压缩", "Pack");
        UnpackTabHeaderText.Text = T("脱壳", "Unpack");
        BenchmarkTabHeaderText.Text = T("启动测试", "Startup benchmark");
        ((ComboBoxItem)LanguageBox.Items[0]!).Content = "中文";
        ((ComboBoxItem)LanguageBox.Items[1]!).Content = "English";

        DropZoneTitleText.Text = T("拖入要压缩的可执行程序，或点击这里选择", "Drop an executable here, or click to choose one");
        SelectedFileText.Text = _inputPath ?? T("尚未选择文件", "No file selected");
        SelectFileButton.Content = T("选择文件", "Choose file");
        AlgorithmLabelText.Text = T("压缩算法", "Compression algorithm");
        ((ComboBoxItem)AlgorithmBox.Items[0]!).Content = T("misa77（推荐：解压优先）", "misa77 (recommended: decompression first)");
        ((ComboBoxItem)AlgorithmBox.Items[1]!).Content = T("LZ4（快速压缩）", "LZ4 (fast compression)");
        PackExecutionTitleText.Text = T("输出与执行", "Output and execution");
        OutputLabelText.Text = T("输出文件", "Output file");
        OutputPathBox.PlaceholderText = T("默认在源文件目录创建 xxx-packed.exe", "Defaults to xxx-packed next to the source");
        ReleaseMemoryCheckBox.Content = T("压缩完成后释放解压工作集内存（--release-memory）", "Reclaim decompression working-set memory (--release-memory)");
        ReleaseMemoryWarningText.Text = T("部分程序可能无法启动，请自行测试。", "May prevent some programs from starting. Test it yourself.");
        ToolTip.SetTip(GitHubButton, "https://github.com/fvffv/UPXEX/");
        PackButton.Content = T("开始压缩", "Start packing");

        UnpackTitleText.Text = T("UPX 脱壳", "UPX unpack");
        UnpackHintText.Text = T("拖入或选择由 UPX 压缩的文件，调用 --decompress 输出其解压副本。", "Drop or choose a UPX-packed file and create an unpacked copy with --decompress.");
        UnpackInputLabelText.Text = T("拖入 UPX 压缩文件，或点击这里选择", "Drop a UPX-packed file here, or click to choose one");
        UnpackOutputLabelText.Text = T("脱壳输出", "Unpacked output");
        SelectUnpackInputButton.Content = T("选择文件", "Choose file");
        UnpackButton.Content = T("开始脱壳", "Start unpacking");
        UnpackStatusText.Text = T("准备就绪", "Ready");

        BenchmarkTitleText.Text = T("启动时间对比", "Startup time comparison");
        BenchmarkHintText.Text = T("仅支持 Windows GUI 程序；每轮随机交错启动原文件和压缩文件。", "Windows GUI applications only. Each round is randomly interleaved; only processes started by this tool are closed.");
        OriginalFileLabelText.Text = T("原文件", "Original file");
        PackedFileLabelText.Text = T("压缩文件", "Packed file");
        SelectOriginalBenchmarkButton.Content = T("选择文件", "Choose file");
        SelectPackedBenchmarkButton.Content = T("选择文件", "Choose file");
        RoundsLabelText.Text = T("每个文件轮数", "Rounds per file");
        BenchmarkButton.Content = T("开始测试", "Run benchmark");
        BenchmarkMethodText.Text = GetBenchmarkMethodDescription();
        BenchmarkStatusText.Text = T("准备就绪", "Ready");
        FooterText.Text = T("misa77 仅适用于包含对应运行时解码器的定制 UPX。", "misa77 requires a customized UPX build containing its runtime decoder.");

        UpdateAlgorithmPresentation();
        UpdateBenchmarkAvailability();
    }

    private string T(string chinese, string english) => _language == UiLanguage.Chinese ? chinese : english;

    private void Language_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (sender is ComboBox { SelectedItem: ComboBoxItem selected })
        {
            _language = selected.Tag?.ToString() == "en" ? UiLanguage.English : UiLanguage.Chinese;
            ApplyLanguage();
        }
    }

    private void Algorithm_SelectionChanged(object? sender, SelectionChangedEventArgs e) => UpdateAlgorithmPresentation();

    private void GitHub_Click(object? sender, RoutedEventArgs e)
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = "https://github.com/fvffv/UPXEX/",
            UseShellExecute = true,
        });
    }

    private void Level_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (LevelBox.SelectedItem is LevelOption level)
        {
            LevelDescription.Text = level.Description;
        }
    }

    private void UpdateAlgorithmPresentation()
    {
        if (AlgorithmBox.SelectedItem is not ComboBoxItem selected)
        {
            return;
        }

        if (selected.Tag?.ToString() == "lz4")
        {
            AlgorithmDescription.Text = T("LZ4 使用 --lz4-acceleration 参数调节压缩速度与体积。", "LZ4 uses --lz4-acceleration to trade compression speed for size.");
            LevelLabel.Text = "LZ4 Acceleration";
            PopulateLz4Levels();
        }
        else
        {
            AlgorithmDescription.Text = T("默认推荐：misa77 等级 1，适合更快启动。", "Recommended default: misa77 level 1 for faster startup.");
            LevelLabel.Text = T("misa77 等级", "misa77 level");
            PopulateMisa77Levels();
        }
    }

    private void PopulateMisa77Levels()
    {
        LevelBox.ItemsSource = new[]
        {
            new LevelOption("-1", "-1", T("等级 -1：最快压缩，压缩率最低", "Level -1: fastest packing, lowest ratio")),
            new LevelOption("0", "0", T("等级 0：快速压缩", "Level 0: fast compression")),
            new LevelOption("1", T("1（推荐）", "1 (recommended)"), T("等级 1（推荐）：解压速度最快体积平衡", "Level 1 (recommended): Fastest decompression with balanced size")),
            new LevelOption("2", "2", T("等级 2：更高压缩率", "Level 2: higher compression ratio")),
            new LevelOption("3", "3", T("等级 3：更高压缩率，压缩时间更长", "Level 3: higher ratio, longer compression time")),
            new LevelOption("4", "4", T("等级 4：最高压缩率，使用 heavy 流", "Level 4: highest ratio, uses the heavy stream")),
        };
        LevelBox.SelectedIndex = 2;
        LevelDescription.Text = ((LevelOption)LevelBox.SelectedItem!).Description;
    }

    private void PopulateLz4Levels()
    {
        LevelBox.ItemsSource = new[]
        {
            new LevelOption("1", "1", T("Acceleration 1：压缩率较高", "Acceleration 1: higher compression ratio")),
            new LevelOption("8", "8", T("Acceleration 8：快速压缩", "Acceleration 8: fast compression")),
            new LevelOption("16", T("16（默认）", "16 (default)"), T("Acceleration 16：默认快速压缩", "Acceleration 16: default fast compression")),
            new LevelOption("64", "64", T("Acceleration 64：优先压缩速度", "Acceleration 64: prioritizes compression speed")),
            new LevelOption("256", "256", T("Acceleration 256：极快压缩，压缩率会下降", "Acceleration 256: very fast compression, lower ratio")),
        };
        LevelBox.SelectedIndex = 2;
        LevelDescription.Text = ((LevelOption)LevelBox.SelectedItem!).Description;
    }

    private async void SelectFile_Click(object? sender, RoutedEventArgs e) => SetInputFile(await PickFileAsync(T("选择要压缩的可执行文件", "Choose executable to pack")));

    private async void SelectFile_PointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (e.Source is Visual source && source.FindAncestorOfType<Button>() is not null)
        {
            return;
        }

        if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
        {
            SetInputFile(await PickFileAsync(T("选择要压缩的可执行文件", "Choose executable to pack")));
        }
    }

    private async Task<string?> PickFileAsync(string title)
    {
        var files = await StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            Title = title,
            AllowMultiple = false,
            FileTypeFilter = new[] { new FilePickerFileType(T("所有文件", "All files")) { Patterns = new[] { "*" } } },
        });
        return files.Count > 0 ? files[0].TryGetLocalPath() : null;
    }

    private void TargetFile_Drop(object? sender, DragEventArgs e) => SetInputFile(e.DataTransfer.TryGetFiles()?.FirstOrDefault()?.TryGetLocalPath());

    private void SetInputFile(string? filePath)
    {
        if (!ValidateExistingFile(filePath, StatusText))
        {
            return;
        }

        _inputPath = filePath;
        SelectedFileText.Text = filePath;
        OutputPathBox.Text = GetDerivedPath(filePath!, "-packed");
        PackButton.IsEnabled = File.Exists(_upxPath);
        StatusText.Text = T("文件已选择，可以开始压缩", "File selected. Ready to pack.");
    }

    private async void Pack_Click(object? sender, RoutedEventArgs e)
    {
        if (!ValidateExistingFile(_inputPath, StatusText))
        {
            return;
        }

        var outputPath = OutputPathBox.Text?.Trim();
        if (!ValidateOutputPath(outputPath, _inputPath!, StatusText))
        {
            return;
        }

        var replaceExistingOutput = File.Exists(outputPath);
        if (replaceExistingOutput && !await ConfirmOverwriteAsync(outputPath!))
        {
            return;
        }

        var algorithm = (AlgorithmBox.SelectedItem as ComboBoxItem)?.Tag?.ToString() ?? "misa77";
        if (LevelBox.SelectedItem is not LevelOption level)
        {
            StatusText.Text = T("请选择等级", "Choose a level first.");
            return;
        }

        var arguments = BuildPackArguments(algorithm, level.Value, outputPath!, _inputPath!);
        await ExecuteUpxAsync(arguments, outputPath!, PackButton, StatusText, LogTextBox, T("正在压缩…", "Packing…"), T("完成：", "Complete: "));
    }

    private string BuildPackArguments(string algorithm, string level, string outputPath, string inputPath)
    {
        // NativeAOT Win32 executables may carry a non-empty exception directory.
        // The customized UPX can pack them, but its conservative PE check requires --force.
        var options = new List<string> { "--force" };
        if (algorithm == "lz4")
        {
            options.Add("--lz4");
            options.Add($"--lz4-acceleration={level}");
        }
        else
        {
            options.Add($"--misa77-level={level}");
        }

        if (ReleaseMemoryCheckBox.IsChecked == true)
        {
            options.Add("--release-memory");
        }

        options.Add("-o");
        options.Add(Quote(outputPath));
        options.Add(Quote(inputPath));
        return string.Join(' ', options);
    }

    private async void SelectUnpackInput_Click(object? sender, RoutedEventArgs e)
    {
        SetUnpackInputFile(await PickFileAsync(T("选择要脱壳的 UPX 文件", "Choose UPX-packed file to unpack")));
    }

    private async void SelectUnpackInput_PointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (e.Source is Visual source && source.FindAncestorOfType<Button>() is not null)
        {
            return;
        }

        if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
        {
            SetUnpackInputFile(await PickFileAsync(T("选择要脱壳的 UPX 文件", "Choose UPX-packed file to unpack")));
        }
    }

    private void UnpackFile_Drop(object? sender, DragEventArgs e) => SetUnpackInputFile(e.DataTransfer.TryGetFiles()?.FirstOrDefault()?.TryGetLocalPath());

    private void SetUnpackInputFile(string? path)
    {
        if (!ValidateExistingFile(path, UnpackStatusText))
        {
            return;
        }

        _unpackInputPath = path;
        UnpackInputBox.Text = path;
        UnpackOutputBox.Text = GetDerivedPath(path!, "-unpacked");
        UnpackButton.IsEnabled = File.Exists(_upxPath);
        UnpackStatusText.Text = T("文件已选择，可以开始脱壳", "File selected. Ready to unpack.");
    }

    private async void Unpack_Click(object? sender, RoutedEventArgs e)
    {
        if (!ValidateExistingFile(_unpackInputPath, UnpackStatusText))
        {
            return;
        }

        var outputPath = UnpackOutputBox.Text?.Trim();
        if (!ValidateOutputPath(outputPath, _unpackInputPath!, UnpackStatusText))
        {
            return;
        }

        var replaceExistingOutput = File.Exists(outputPath);
        if (replaceExistingOutput && !await ConfirmOverwriteAsync(outputPath!))
        {
            return;
        }

        var options = new List<string> { "--decompress" };
        if (replaceExistingOutput)
        {
            options.Add("--force");
        }

        options.Add("-o");
        options.Add(Quote(outputPath!));
        options.Add(Quote(_unpackInputPath!));
        await ExecuteUpxAsync(string.Join(' ', options), outputPath!, UnpackButton, UnpackStatusText, UnpackLogTextBox, T("正在脱壳…", "Unpacking…"), T("完成：", "Complete: "));
    }

    private async Task ExecuteUpxAsync(string arguments, string outputPath, Button actionButton, TextBlock statusText, TextBox logTextBox, string runningText, string completedPrefix)
    {
        actionButton.IsEnabled = false;
        statusText.Text = runningText;
        logTextBox.Text = string.Empty;
        AppendLog(logTextBox, $"> {Quote(_upxPath)} {arguments}");

        try
        {
            var result = await RunUpxAsync(arguments);
            AppendLog(logTextBox, result.Output);
            statusText.Text = result.ExitCode == 0 && File.Exists(outputPath)
                ? completedPrefix + Path.GetFileName(outputPath)
                : T($"操作失败，UPX 退出码 {result.ExitCode}", $"Operation failed. UPX exit code: {result.ExitCode}");
        }
        catch (Exception ex)
        {
            AppendLog(logTextBox, ex.ToString());
            statusText.Text = T("启动 UPX 失败", "Could not start UPX.");
        }
        finally
        {
            actionButton.IsEnabled = File.Exists(_upxPath);
        }
    }

    private async void SelectOriginalBenchmark_Click(object? sender, RoutedEventArgs e)
    {
        var path = await PickFileAsync(T("选择原文件", "Choose original file"));
        if (ValidateExistingFile(path, BenchmarkStatusText))
        {
            OriginalBenchmarkPathBox.Text = path;
        }
    }

    private async void SelectPackedBenchmark_Click(object? sender, RoutedEventArgs e)
    {
        var path = await PickFileAsync(T("选择压缩文件", "Choose packed file"));
        if (ValidateExistingFile(path, BenchmarkStatusText))
        {
            PackedBenchmarkPathBox.Text = path;
        }
    }

    private async void Benchmark_Click(object? sender, RoutedEventArgs e)
    {
        if (!OperatingSystem.IsWindows())
        {
            BenchmarkStatusText.Text = T("启动测试仅支持 Windows GUI 程序。", "Startup benchmarking is supported only for Windows GUI applications.");
            return;
        }

        var originalPath = OriginalBenchmarkPathBox.Text?.Trim();
        var packedPath = PackedBenchmarkPathBox.Text?.Trim();
        if (!ValidateExistingFile(originalPath, BenchmarkStatusText) || !ValidateExistingFile(packedPath, BenchmarkStatusText))
        {
            return;
        }

        if (RoundsBox.SelectedItem is not ComboBoxItem { Content: string roundsText } || !int.TryParse(roundsText, out var rounds))
        {
            BenchmarkStatusText.Text = T("请选择测试轮数", "Choose the number of rounds.");
            return;
        }

        BenchmarkButton.IsEnabled = false;
        BenchmarkResultTextBox.Text = string.Empty;
        BenchmarkStatusText.Text = T("正在测试…", "Benchmark running…");

        try
        {
            var report = await RunBenchmarkAsync(originalPath!, packedPath!, rounds);
            BenchmarkResultTextBox.Text = report;
            BenchmarkStatusText.Text = T("测试完成", "Benchmark complete.");
        }
        catch (Exception ex)
        {
            BenchmarkResultTextBox.Text = ex.ToString();
            BenchmarkStatusText.Text = T("测试失败", "Benchmark failed.");
        }
        finally
        {
            BenchmarkButton.IsEnabled = OperatingSystem.IsWindows();
        }
    }

    private async Task<string> RunBenchmarkAsync(string originalPath, string packedPath, int rounds)
    {
        if (!OperatingSystem.IsWindows())
        {
            throw new PlatformNotSupportedException("Startup benchmarking is supported only for Windows GUI applications.");
        }

        var samplesToRun = new List<BenchmarkTarget>(rounds * 2);
        for (var index = 0; index < rounds; index++)
        {
            samplesToRun.Add(new BenchmarkTarget(T("原文件", "Original"), originalPath));
            samplesToRun.Add(new BenchmarkTarget(T("压缩文件", "Packed"), packedPath));
        }

        for (var index = samplesToRun.Count - 1; index > 0; index--)
        {
            var otherIndex = Random.Shared.Next(index + 1);
            (samplesToRun[index], samplesToRun[otherIndex]) = (samplesToRun[otherIndex], samplesToRun[index]);
        }

        var samples = new List<StartupSample>(samplesToRun.Count);
        foreach (var target in samplesToRun)
        {
            samples.Add(await MeasureStartupAsync(target));
        }

        return BuildBenchmarkReport(samples, originalPath, packedPath, rounds);
    }

    private static async Task<StartupSample> MeasureStartupAsync(BenchmarkTarget target)
    {
        using var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = target.Path,
                WorkingDirectory = Path.GetDirectoryName(target.Path) ?? AppContext.BaseDirectory,
                UseShellExecute = false,
                CreateNoWindow = true,
            },
        };

        var stopwatch = Stopwatch.StartNew();
        if (!process.Start())
        {
            throw new InvalidOperationException($"Could not start {target.Path}.");
        }

        try
        {
            try
            {
                var inputIdle = await Task.Run(() => process.WaitForInputIdle(StartupTimeoutMilliseconds));
                if (!inputIdle)
                {
                    throw new TimeoutException($"Timed out waiting for input idle: {target.Path}");
                }
            }
            catch (InvalidOperationException exception)
            {
                throw new InvalidOperationException(
                    $"Startup benchmarking requires a Windows GUI process with an input queue: {target.Path}",
                    exception);
            }

            if (process.HasExited)
            {
                throw new InvalidOperationException($"Process exited during startup: {target.Path} (code {process.ExitCode}).");
            }

            return new StartupSample(target.Label, target.Path, stopwatch.Elapsed.TotalMilliseconds, "WaitForInputIdle");
        }
        finally
        {
            await StopBenchmarkProcessAsync(process);
        }
    }

    private static async Task StopBenchmarkProcessAsync(Process process)
    {
        if (process.HasExited)
        {
            return;
        }

        try
        {
            if (process.CloseMainWindow())
            {
                await process.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(2));
            }
        }
        catch (TimeoutException)
        {
            // The application did not honor the close request; force-stop only
            // this benchmark's owned process tree below.
        }
        catch (InvalidOperationException)
        {
            // It may have exited while closing.
        }

        if (!process.HasExited)
        {
            process.Kill(entireProcessTree: true);
            await process.WaitForExitAsync();
        }
    }

    private string BuildBenchmarkReport(IReadOnlyList<StartupSample> samples, string originalPath, string packedPath, int rounds)
    {
        var original = samples.Where(sample => sample.Path == originalPath).Select(sample => sample.Milliseconds).ToArray();
        var packed = samples.Where(sample => sample.Path == packedPath).Select(sample => sample.Milliseconds).ToArray();
        var builder = new StringBuilder();
        builder.AppendLine(T("启动时间报告", "Startup benchmark report"));
        builder.AppendLine($"{T("方法", "Method")}: {GetBenchmarkMethodDescription()}");
        builder.AppendLine($"{T("轮数", "Rounds")}: {rounds} × 2 ({T("随机交错", "randomized interleaving")})");
        builder.AppendLine();
        AppendStatistics(builder, T("原文件", "Original"), original);
        AppendStatistics(builder, T("压缩文件", "Packed"), packed);

        var difference = packed.Average() - original.Average();
        var ratio = difference / original.Average() * 100;
        builder.AppendLine();
        builder.AppendLine(T("平均差异（压缩 - 原文件）", "Mean difference (packed - original)") + $": {difference:+0.0;-0.0;0.0} ms ({ratio:+0.0;-0.0;0.0}%)");
        builder.AppendLine();
        builder.AppendLine(T("逐次样本", "Samples"));
        for (var index = 0; index < samples.Count; index++)
        {
            var sample = samples[index];
            builder.AppendLine($"{index + 1,2}. {sample.Label,-10} {sample.Milliseconds,8:0.0} ms  [{sample.Method}]");
        }

        return builder.ToString();
    }

    private static void AppendStatistics(StringBuilder builder, string name, IReadOnlyList<double> values)
    {
        var ordered = values.OrderBy(value => value).ToArray();
        var median = ordered.Length % 2 == 1
            ? ordered[ordered.Length / 2]
            : (ordered[(ordered.Length / 2) - 1] + ordered[ordered.Length / 2]) / 2;
        builder.AppendLine($"{name}: mean {values.Average():0.0} ms | median {median:0.0} ms | min {ordered[0]:0.0} ms | max {ordered[^1]:0.0} ms");
    }

    private string GetBenchmarkMethodDescription() => T(
        "Windows GUI：从进程创建计时到 WaitForInputIdle 返回。",
        "Windows GUI: process creation to WaitForInputIdle.");

    private void UpdateBenchmarkAvailability()
    {
        var supported = OperatingSystem.IsWindows();
        BenchmarkContentGrid.IsEnabled = supported;

        if (!supported)
        {
            BenchmarkResultTextBox.Text = T(
                "当前平台不支持启动测试。\n\n仅支持 Windows GUI 程序，因为测试以 WaitForInputIdle 作为可重复的近似“可交互”终点。",
                "Startup benchmarking is unavailable on this platform.\n\nIt is supported only for Windows GUI applications, where WaitForInputIdle provides a repeatable approximate interactive-ready endpoint.");
            BenchmarkStatusText.Text = T("仅支持 Windows GUI 程序", "Windows GUI applications only");
        }
    }

    private static string GetDerivedPath(string path, string suffix) => Path.Combine(Path.GetDirectoryName(path)!, $"{Path.GetFileNameWithoutExtension(path)}{suffix}{Path.GetExtension(path)}");

    private bool ValidateExistingFile(string? path, TextBlock statusText)
    {
        if (!string.IsNullOrWhiteSpace(path) && File.Exists(path))
        {
            return true;
        }

        statusText.Text = T("请选择存在的本地文件", "Choose an existing local file.");
        return false;
    }

    private bool ValidateOutputPath(string? outputPath, string inputPath, TextBlock statusText)
    {
        if (string.IsNullOrWhiteSpace(outputPath))
        {
            statusText.Text = T("请指定输出文件", "Specify an output file.");
            return false;
        }

        if (Path.GetFullPath(outputPath).Equals(Path.GetFullPath(inputPath), StringComparison.OrdinalIgnoreCase))
        {
            statusText.Text = T("输出文件不能覆盖源文件", "Output file cannot overwrite the source file.");
            return false;
        }

        return true;
    }

    private async Task<bool> ConfirmOverwriteAsync(string outputPath)
    {
        var dialog = new Window
        {
            Title = T("确认覆盖", "Confirm overwrite"),
            Width = 450,
            Height = 180,
            CanResize = false,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Content = new StackPanel
            {
                Margin = new Thickness(22),
                Spacing = 18,
                Children =
                {
                    new TextBlock { Text = T($"输出文件已存在：\n{Path.GetFileName(outputPath)}", $"Output file already exists:\n{Path.GetFileName(outputPath)}"), TextWrapping = TextWrapping.Wrap },
                    new StackPanel
                    {
                        Orientation = Orientation.Horizontal,
                        HorizontalAlignment = HorizontalAlignment.Right,
                        Spacing = 8,
                        Children =
                        {
                            new Button { Content = T("取消", "Cancel"), IsCancel = true },
                            new Button { Content = T("覆盖", "Overwrite"), IsDefault = true },
                        },
                    },
                },
            },
        };

        var buttons = ((StackPanel)((StackPanel)dialog.Content).Children[1]).Children;
        ((Button)buttons[0]).Click += (_, _) => dialog.Close(false);
        ((Button)buttons[1]).Click += (_, _) => dialog.Close(true);
        return await dialog.ShowDialog<bool>(this);
    }

    private async Task<ProcessResult> RunUpxAsync(string arguments)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = _upxPath,
            Arguments = arguments,
            WorkingDirectory = Path.GetDirectoryName(_upxPath) ?? AppContext.BaseDirectory,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
        };

        using var process = new Process { StartInfo = startInfo };
        process.Start();
        var standardOutput = process.StandardOutput.ReadToEndAsync();
        var standardError = process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();
        return new ProcessResult(process.ExitCode, (await standardOutput) + (await standardError));
    }

    private static string Quote(string path) => $"\"{path.Replace("\"", "\\\"")}\"";

    private static void AppendLog(TextBox textBox, string text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return;
        }

        textBox.Text += (textBox.Text?.Length > 0 ? Environment.NewLine : string.Empty) + text.TrimEnd();
        textBox.CaretIndex = textBox.Text?.Length ?? 0;
    }

    private enum UiLanguage
    {
        Chinese,
        English,
    }

    private sealed record LevelOption(string Value, string Display, string Description)
    {
        public override string ToString() => Display;
    }

    private sealed record ProcessResult(int ExitCode, string Output);

    private sealed record BenchmarkTarget(string Label, string Path);

    private sealed record StartupSample(string Label, string Path, double Milliseconds, string Method);
}
