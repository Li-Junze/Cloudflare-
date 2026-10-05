# ============================================================
#  Ui.ps1 —— 界面定义（XAML + 主题色）
# ============================================================

$script:Theme = @{
    Bg      = '#F5F7FB'
    Card    = '#FFFFFF'
    Line    = '#E4E8F0'
    Text    = '#1F2937'
    Sub     = '#6B7280'
    Accent  = '#F6821F'
    Blue    = '#2563EB'
    Green   = '#16A34A'
    LogBg   = '#1E2430'
    LogText = '#D6DEE8'
}

function Get-MainWindowXaml {
    $C = $script:Theme
    return @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Cloudflare 网页部署" Height="740" Width="940"
        WindowStartupLocation="CenterScreen"
        Background="$($C.Bg)" FontFamily="Microsoft YaHei UI" FontSize="13"
        ResizeMode="CanResize" MinHeight="620" MinWidth="820">
  <Window.Resources>
    <Style x:Key="BtnBase" TargetType="Button">
      <Setter Property="Padding" Value="16,10"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" CornerRadius="8" Background="{TemplateBinding Background}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"
                                Margin="{TemplateBinding Padding}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Opacity" Value="0.86"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="bd" Property="Opacity" Value="0.45"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="BtnPrimary" TargetType="Button" BasedOn="{StaticResource BtnBase}">
      <Setter Property="Background" Value="$($C.Accent)"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Padding" Value="20,12"/>
    </Style>
    <Style x:Key="BtnGhost" TargetType="Button" BasedOn="{StaticResource BtnBase}">
      <Setter Property="Background" Value="#EEF1F7"/>
      <Setter Property="Foreground" Value="$($C.Text)"/>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Padding" Value="10,8"/>
      <Setter Property="BorderBrush" Value="$($C.Line)"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Background" Value="White"/>
      <Setter Property="Foreground" Value="$($C.Text)"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border CornerRadius="8" Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}">
              <ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Border Grid.Row="0" Background="White" BorderBrush="$($C.Line)" BorderThickness="0,0,0,1" Padding="24,16">
      <Grid>
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <Border Width="34" Height="34" CornerRadius="9" Background="$($C.Accent)">
            <TextBlock Text="CF" Foreground="White" FontWeight="Bold" FontSize="15"
                       HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <StackPanel Margin="12,0,0,0" VerticalAlignment="Center">
            <TextBlock Text="Cloudflare 网页部署" FontSize="16" FontWeight="SemiBold" Foreground="$($C.Text)"/>
            <TextBlock Text="选择文件夹 → 点部署 → 拿到公网地址" FontSize="11.5" Foreground="$($C.Sub)" Margin="0,2,0,0"/>
          </StackPanel>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
          <Ellipse x:Name="DotState" Width="9" Height="9" Fill="#9CA3AF" VerticalAlignment="Center"/>
          <TextBlock x:Name="TxtState" Text="检查登录中…" Margin="7,0,0,0" FontSize="12" Foreground="$($C.Sub)" VerticalAlignment="Center"/>
        </StackPanel>
      </Grid>
    </Border>

    <Border Grid.Row="1" Background="White" CornerRadius="12" Margin="24,20,24,12" Padding="22,20">
      <Border.Effect>
        <DropShadowEffect BlurRadius="14" ShadowDepth="1" Opacity="0.06" Color="#000000"/>
      </Border.Effect>
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>

        <TextBlock Grid.Row="0" Grid.Column="0" Text="网站文件夹" Foreground="$($C.Sub)" VerticalAlignment="Center" Width="76"/>
        <TextBox   Grid.Row="0" Grid.Column="1" x:Name="TxtDir" Margin="0,0,10,0"/>
        <Button    Grid.Row="0" Grid.Column="2" x:Name="BtnBrowse" Content="浏览…" Style="{StaticResource BtnGhost}"/>
        <TextBlock Grid.Row="1" Grid.Column="1" x:Name="TxtDirHint" Margin="2,6,0,0"
                   Text="文件夹里要有 index.html" FontSize="11" Foreground="$($C.Sub)"/>

        <TextBlock Grid.Row="2" Grid.Column="0" Text="项目名称" Foreground="$($C.Sub)" VerticalAlignment="Center" Margin="0,18,0,0"/>
        <TextBox   Grid.Row="2" Grid.Column="1" x:Name="TxtName" Margin="0,18,10,0" MaxLength="58"/>
        <TextBlock Grid.Row="3" Grid.Column="1" x:Name="TxtNameHint" Margin="2,6,0,0"
                   Text="只能是 小写字母 / 数字 / 连字符，会自动纠正" FontSize="11" Foreground="$($C.Sub)"/>
        <TextBlock Grid.Row="3" Grid.Column="2" x:Name="TxtUrl" Margin="0,6,0,0"
                   FontSize="11.5" Foreground="$($C.Blue)" HorizontalAlignment="Right"/>
      </Grid>
    </Border>

    <Border Grid.Row="2" Background="$($C.LogBg)" CornerRadius="12" Margin="24,0,24,12">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <Grid Grid.Row="0" Margin="18,12,18,0">
          <TextBlock Text="运行日志" Foreground="#8C99AC" FontSize="11.5" FontWeight="SemiBold"/>
          <Button x:Name="BtnClear" Content="清空" HorizontalAlignment="Right"
                  Background="Transparent" Foreground="#8C99AC" BorderThickness="0"
                  Cursor="Hand" FontSize="11.5" Padding="6,0"/>
        </Grid>
        <TextBox Grid.Row="1" x:Name="TxtLog" Margin="12,6,12,12" IsReadOnly="True"
                 Background="Transparent" Foreground="$($C.LogText)" BorderThickness="0"
                 FontFamily="Cascadia Mono, Consolas, Courier New" FontSize="12"
                 TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"
                 VerticalContentAlignment="Top" Padding="6,2"/>
      </Grid>
    </Border>

    <Border Grid.Row="3" Background="White" BorderBrush="$($C.Line)" BorderThickness="0,1,0,0" Padding="24,14">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
          <Button x:Name="BtnLogin"  Content="登录账号"  Style="{StaticResource BtnGhost}" Margin="0,0,8,0"/>
          <Button x:Name="BtnManage" Content="项目管理"  Style="{StaticResource BtnGhost}" Margin="0,0,8,0"/>
          <Button x:Name="BtnOpen"   Content="打开控制台" Style="{StaticResource BtnGhost}"/>
        </StackPanel>
        <ProgressBar Grid.Column="1" x:Name="PBar" Height="6" Margin="20,0"
                     VerticalAlignment="Center" Foreground="$($C.Accent)"
                     Background="#EEF1F7" BorderThickness="0" Visibility="Hidden"/>
        <Button Grid.Column="2" x:Name="BtnDeploy" Content="开始部署"
                Style="{StaticResource BtnPrimary}" MinWidth="140"/>
      </Grid>
    </Border>
  </Grid>
</Window>
"@
}

function Get-ProjectsWindowXaml {
    return @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="项目管理" Height="440" Width="780" WindowStartupLocation="CenterOwner"
        Background="#F5F7FB" FontFamily="Microsoft YaHei UI" FontSize="13">
  <Grid Margin="18">
    <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
    <Border Grid.Row="0" Background="White" CornerRadius="10" Padding="12">
      <ListBox x:Name="LbProjects" BorderThickness="0" FontFamily="Cascadia Mono, Consolas" FontSize="12.5"/>
    </Border>
    <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,14,0,0">
      <Button x:Name="BRefresh"  Content="刷新"        Padding="16,9" Margin="0,0,8,0"/>
      <Button x:Name="BOpenSite" Content="打开选中站点" Padding="16,9" Margin="0,0,8,0"/>
      <Button x:Name="BDelete"   Content="删除选中项目" Padding="16,9" Margin="0,0,8,0"/>
      <Button x:Name="BClose"    Content="关闭"        Padding="16,9"/>
    </StackPanel>
  </Grid>
</Window>
"@
}
