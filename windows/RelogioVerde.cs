using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;
using System.Runtime.InteropServices;

// Independent recreation based on a reference photograph. No external assets.
internal static class Program {
    [STAThread] static void Main(string[] args) {
        try {
            Application.SetUnhandledExceptionMode(UnhandledExceptionMode.ThrowException);
            Run(args);
        } catch (Exception ex) {
            try {
                string folder = System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "RelogioVerde");
                System.IO.Directory.CreateDirectory(folder);
                System.IO.File.WriteAllText(System.IO.Path.Combine(folder,"erro-execucao.txt"), DateTime.Now.ToString("s") + "\r\n" + ex.ToString());
            } catch { }
            Environment.ExitCode = 1;
        }
    }
    static void Run(string[] args) {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        string arg = args.Length > 0 ? args[0].ToLowerInvariant() : "/s";
        if (arg.StartsWith("/c") || arg.StartsWith("-c")) {
            MessageBox.Show("Relógio Verde\n\nHora local em formato de 24 horas.\nPonto fixo; círculo interno: 24 horas; externo: 60 minutos.\nPara sair: mova o mouse ou pressione uma tecla.\n\nRecriação independente baseada em uma fotografia.", "Relógio Verde");
            return;
        }
        if (arg.StartsWith("/p") || arg.StartsWith("-p")) {
            string handle = arg.Length > 3 ? arg.Substring(3) : (args.Length > 1 ? args[1] : "");
            long n;
            if (Int64.TryParse(handle, out n) && n != 0) Application.Run(new ClockForm(new IntPtr(n)));
            return;
        }
        if (arg == "/render" && args.Length > 1) {
            using (Bitmap bmp = new Bitmap(1280, 800)) {
                using (Graphics g = Graphics.FromImage(bmp)) ClockArt.Paint(g, 1280, 800, new DateTime(2026,1,1,1,13,12), 0);
                bmp.Save(args[1], System.Drawing.Imaging.ImageFormat.Png);
            }
            return;
        }
        foreach (Screen screen in Screen.AllScreens) { ClockForm f = new ClockForm(screen.Bounds); f.Show(); }
        Cursor.Hide();
        try { Application.Run(); } finally { Cursor.Show(); }
    }
}
internal sealed class ClockForm : Form {
    readonly Timer timer = new Timer();
    readonly DateTime started = DateTime.UtcNow;
    readonly Point initial = Cursor.Position;
    bool preview;
    IntPtr host;
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] static extern IntPtr SetParent(IntPtr child, IntPtr parent);
    [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr hwnd, int index, int value);
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] static extern bool IsWindow(IntPtr hwnd);
    public ClockForm(Rectangle bounds) { Setup(); Bounds = bounds; TopMost = true; }
    public ClockForm(IntPtr parent) {
        preview = true; host = parent; Setup();
        SetWindowLong(Handle, -16, unchecked((int)0x50000000));
        SetParent(Handle, parent); ResizePreview();
    }
    void ResizePreview() { Rect r; if (GetClientRect(host, out r)) Bounds = new Rectangle(0,0,r.Right-r.Left,r.Bottom-r.Top); }
    void Setup() {
        FormBorderStyle = FormBorderStyle.None; StartPosition = FormStartPosition.Manual;
        ShowInTaskbar = false; BackColor = Color.Black; DoubleBuffered = true; KeyPreview = true;
        timer.Interval = 100;
        timer.Tick += delegate {
            if (preview) { if (!IsWindow(host)) { Close(); return; } ResizePreview(); }
            else if ((DateTime.UtcNow-started).TotalSeconds > 1.5 &&
                (Math.Abs(Cursor.Position.X-initial.X)>8 || Math.Abs(Cursor.Position.Y-initial.Y)>8)) Application.Exit();
            Invalidate();
        };
        timer.Start();
        KeyDown += delegate { if (!preview) Application.Exit(); };
        MouseDown += delegate { if (!preview) Application.Exit(); };
        FormClosed += delegate { timer.Dispose(); if (!preview) Application.ExitThread(); };
    }
    protected override void OnPaint(PaintEventArgs e) {
        ClockArt.Paint(e.Graphics, ClientSize.Width, ClientSize.Height, DateTime.Now, (DateTime.UtcNow-started).TotalSeconds);
    }
}
internal static class ClockArt {
    static readonly int[] Masks = { 63,6,91,79,102,109,125,7,127,111 };
    public static void Paint(Graphics g, int width, int height, DateTime now, double elapsed) {
        g.Clear(Color.Black); g.SmoothingMode = SmoothingMode.AntiAlias;
        float scale = Math.Min(width/900f, height/760f);
        g.TranslateTransform(width/2f, height/2f);
        g.ScaleTransform(scale,scale);
        double seconds = now.Second + now.Millisecond / 1000.0;
        double minutes = now.Minute + seconds / 60.0;
        double hours = now.Hour + minutes / 60.0;
        Ring(g, 235, minutes / 60.0);
        Ring(g, 195, hours / 24.0);
        Glow(g,0,0,0,0.01f,8);
        string time=now.Hour.ToString("00")+":"+now.Minute.ToString("00")+":"+now.Second.ToString("00");
        float total=0; foreach(char c in time) total += c==':' ? 18 : 42;
        float x=-total/2f;
        foreach(char c in time) {
            if(c==':') { Glow(g,x+5,58,x+5,60,3); Glow(g,x+5,83,x+5,85,3); x+=18; }
            else { Digit(g,c-'0',x,40); x+=42; }
        }
        g.ResetTransform();
    }
    static void Ring(Graphics g, float radius, double progress) {
        // 60 luminous segments; the leading segment fills continuously.
        double angle = Math.Max(0, Math.Min(1, progress)) * 360;
        for(int i=0;i<60;i++) {
            float sweep=(float)Math.Min(4.0,angle-i*6.0);
            if(sweep<=0) break;
            for(int k=4;k>=0;k--) {
                Color c=k==0?Color.FromArgb(111,255,185):Color.FromArgb(12,45,255,154);
                using(Pen pen=new Pen(c,5+k*4)) {
                    pen.StartCap=pen.EndCap=LineCap.Round;
                    g.DrawArc(pen,-radius,-radius,radius*2,radius*2,-90+i*6,sweep);
                }
            }
        }
    }
    static void Glow(Graphics g,float x1,float y1,float x2,float y2,float width) {
        for(int i=4;i>=1;i--) using(Pen p=new Pen(Color.FromArgb(12,45,255,154),width+i*4)) { p.StartCap=p.EndCap=LineCap.Round; g.DrawLine(p,x1,y1,x2,y2); }
        using(Pen p=new Pen(Color.FromArgb(111,255,185),width)) { p.StartCap=p.EndCap=LineCap.Round; g.DrawLine(p,x1,y1,x2,y2); }
    }
    static void Digit(Graphics g,int digit,float x,float y) {
        float[,] lines={{5,0,27,0},{30,5,30,26},{30,36,30,57},{5,62,27,62},{2,36,2,57},{2,5,2,26},{5,31,27,31}};
        for(int i=0;i<7;i++) if((Masks[digit]&(1<<i))!=0) Glow(g,x+lines[i,0],y+lines[i,1],x+lines[i,2],y+lines[i,3],3);
    }
}
