#region Script Configuration
# ======================================================================================================================
# 🔧 Ferramenta de Manutenção do Sistema - DuckDev
# Descrição: Script para realizar tarefas comuns de manutenção e reparo do Windows.
# Autor: Marcelo Ajala Alarcon
# Versão: 2.0
# ======================================================================================================================

# Define o comportamento do script, como tratamento de erros.
[CmdletBinding()]
param (
    # Parâmetro para executar a limpeza de forma silenciosa quando agendado.
    [Switch]$ScheduledClean
)
#endregion

#region Funções Auxiliares

# Função para registrar logs e exibir mensagens na tela.
function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor = 'White'
    )
    # Exibe a mensagem no console.
    Write-Host $Message -ForegroundColor $ForegroundColor
}

#endregion


# Função para verificar a presença de antivírus de terceiros.
function Verificar-Antivirus {
    try {
        # Procura por produtos antivírus que NÃO sejam o Windows Defender.
        $avList = Get-CimInstance -Namespace root\SecurityCenter2 -Class AntiVirusProduct | Where-Object { $_.displayName -notlike '*windows*' } | Select-Object -ExpandProperty displayName
        
        # Se encontrar algum, exibe um alerta.
        if ($avList) {
            Write-Host
            Write-Host '🛡️ ALERTA: Antivírus de terceiro detectado!' -ForegroundColor White -BackgroundColor DarkRed
            Write-Host "   Ele pode interferir em algumas operações do script." -ForegroundColor Yellow
            Write-Host "   Antivírus encontrado: $($avList -join ', ')" -ForegroundColor Yellow
            Write-Host
            # Pausa para o usuário ler o alerta.
            Read-Host "Pressione ENTER para continuar..."
        }
    }
    catch {
        # Ignora erros caso não consiga verificar (não é uma função crítica).
    }
}

#region Verificação de Privilégios e Configuração Inicial
# 🚨 Verificação de Privilégios

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    
    Write-Host "⏫ Permissões de administrador necessárias. Reabrindo o script..." -ForegroundColor Yellow
    
    # 1. .Defina AQUI o comando exato que você usa para executar o script
    #    É CRUCIAL que este comando esteja correto.
    $commandToRerun = "irm https://raw.githubusercontent.com/marceloajalaalarcon/ferramentaSistema/refs/heads/main/ferramentasSistema.ps1 | iex"

    # 2. Codificamos o comando para Base64. 
    #    Isso garante que ele seja passado para a nova janela do PowerShell sem erros de interpretação de caracteres.
    #    Pense nisso como colocar o comando em um "envelope seguro".
    $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($commandToRerun))

    # 3. Reinicia o PowerShell com privilégios elevados (-Verb RunAs) e passa o comando codificado.
    #    O parâmetro -EncodedCommand é feito exatamente para isso.
    Start-Process powershell.exe -ArgumentList "-EncodedCommand $encodedCommand" -Verb RunAs
    
    # 4. Encerra o script atual (o que não é admin).
    exit
}
# ======================================================================================================================

function Mostrar-TermoDeUso {
    # Esta função exibe os termos e o menu de opções, e retorna a escolha do usuário.
    while ($true) {
        Clear-Host
        # O Here-String (@" "@) permite formatar textos longos de forma fácil.
        $termo = @"
================================================================================
TERMO DE USO, TRANSPARÊNCIA E OPÇÕES INICIAIS
================================================================================

Olá! Seja bem-vindo à Ferramenta de Manutenção DuckDev.
Autor: Marcelo Ajala Alarcon

Esta ferramenta foi criada para simplificar e automatizar o acesso a
utilitários de manutenção poderosos que já existem nativamente no seu Windows.
O objetivo é ser transparente sobre cada ação executada.

--------------------------------------------------------------------------------
1. O PRINCÍPIO DA TRANSPARÊNCIA: O QUE A FERRAMENTA FAZ
--------------------------------------------------------------------------------

Este script não instala softwares de terceiros. Ele apenas executa comandos
que você mesmo poderia digitar no Prompt de Comando ou PowerShell.

* Ações Principais: sfc /scannow, DISM.exe /RestoreHealth, chkdsk.exe,
  limpeza de arquivos temporários, reset de componentes do Windows Update, etc.

--------------------------------------------------------------------------------
2. OS RISCOS ENVOLVIDOS: SUA RESPONSABILIDADE COMO USUÁRIO
--------------------------------------------------------------------------------

Apesar de usar ferramentas nativas, qualquer operação de manutenção profunda
oferece riscos, especialmente em sistemas personalizados ou com falhas de
hardware pré-existentes.

É ALTAMENTE RECOMENDADO QUE VOCÊ FAÇA UM BACKUP DE SEUS DADOS IMPORTANTES
ANTES DE EXECUTAR QUALQUER OPÇÃO DE REPARO.

--------------------------------------------------------------------------------
3. O ACORDO: TERMO DE RESPONSABILIDADE
--------------------------------------------------------------------------------

Este software é fornecido "COMO ESTÁ", sem garantia de qualquer tipo.
AO USAR ESTE SCRIPT, VOCÊ CONCORDA QUE O AUTOR (MARCELO AJALA ALARCON) NÃO
SERÁ RESPONSABILIZADO por quaisquer danos, incluindo perda de dados ou
instabilidade do sistema. A responsabilidade pelo uso é inteiramente sua.

--------------------------------------------------------------------------------
4. CONFIGURAÇÃO INICIAL (LEIA COM ATENÇÃO)
--------------------------------------------------------------------------------
A única escolha necessária é se você deseja que a ferramenta lembre do seu
consentimento para não exibir esta tela nas próximas vezes.

"@
        Write-Host $termo -ForegroundColor Yellow
        Write-Host "================================================================================" -ForegroundColor Cyan
        Write-Host "[1] Aceitar e Lembrar Consentimento (Recomendado)" -ForegroundColor Green
        Write-Host "    (não mostra esta tela novamente)"
        Write-Host
        Write-Host "[2] Aceitar Apenas para Esta Sessão" -ForegroundColor Yellow
        Write-Host "    (esta tela será exibida na próxima vez)"
        Write-Host
        Write-Host "[0] Recusar e Sair" -ForegroundColor Red
        Write-Host
        
        $escolha = Read-Host "Digite sua escolha"

        # O switch foi simplificado para refletir as novas opções.
        switch ($escolha) {
            '1' { 
                # Prosseguir, salvar o consentimento
                return @{ Action = 'Proceed'; SaveConsent = $true; } 
            }
            '2' { 
                # Prosseguir, NÃO salvar o consentimento e criar o ponto de restauração.
                return @{ Action = 'Proceed'; SaveConsent = $false; } 
            }
            '0' { 
                # Sair do script.
                return @{ Action = 'Exit'; SaveConsent = $false; } 
            }
            default {
                Write-Host "`nOpção inválida. Por favor, tente novamente." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    }
}

# --- VERIFICAÇÃO DO TERMO DE USO E PONTO DE RESTAURAÇÃO ---
$consentFile = Join-Path $env:APPDATA "DuckDevToolConsent.txt"
if (-not (Test-Path $consentFile)) {
    $userChoice = Mostrar-TermoDeUso
    switch ($userChoice.Action) {
        'Proceed' {
            if ($userChoice.SaveConsent) { Set-Content -Path $consentFile -Value "Termos aceitos em $(Get-Date)" | Out-Null }
        }
        'Exit' {
            Write-Host "`nVocê não aceitou os termos. O script será encerrado." -ForegroundColor Red; Start-Sleep -Seconds 3; exit
        }
    }
}

# Configura a janela do PowerShell.
$Host.UI.RawUI.WindowTitle = "🔧 Ferramenta de Manutenção do Sistema - DuckDev v2.0"
$Host.UI.RawUI.ForegroundColor = "White"
$Host.UI.RawUI.BackgroundColor = "DarkBlue"
Clear-Host

Verificar-Antivirus

#endregion

#region Funções do Menu

function Mostrar-Menu {
    Clear-Host
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "    🔧 FERRAMENTA DE MANUTENÇÃO DO SISTEMA" -ForegroundColor White
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host
    Write-Host "--- SISTEMA ---" -ForegroundColor Green
    Write-Host "[1] 🔍 Verificar arquivos do sistema (SFC)"
    Write-Host "[2] 🛠️  Reparo da imagem do sistema (DISM)"
    Write-Host
    Write-Host "--- DISCO ---" -ForegroundColor Green
    Write-Host "[3] 💾 Agendar verificação de disco (CHKDSK)"
    Write-Host "[4] 🧹 Limpeza de arquivos temporários"
    Write-Host "[5] 🧪 Verificar status SMART do disco"
    Write-Host
    Write-Host "--- REDE E ATUALIZAÇÕES ---" -ForegroundColor Green
    Write-Host "[6] 🌐 Cofiguração de rede"
    Write-Host "[7] ♻️ Reiniciar componentes do Windows Update"
    Write-Host
    Write-Host "--- OUTROS ---" -ForegroundColor Green
    Write-Host "[8] 📅 Agendar tarefa de limpeza diária"
    Write-Host "[9] 🖨️ Limpar fila de impressão"
    Write-Host
    Write-Host "--- SAIR ---" -ForegroundColor Red
    Write-Host "[0] ❌ Sair"
    Write-Host
}

function Executar-SFC {
    Clear-Host
    Write-Log "🔍 Executando verificação de arquivos do sistema (SFC)..." -ForegroundColor Yellow
    Write-Log "Este processo pode demorar alguns minutos. Por favor, aguarde."

    # Inicia o processo e aguarda sua conclusão.
    $process = Start-Process sfc.exe -ArgumentList "/scannow" -Wait -PassThru

    if ($process.ExitCode -eq 0) {
        Write-Log "`n✔️ Verificação SFC concluída com sucesso." -ForegroundColor Green
    } else {
        Write-Log "`n❌ Ocorreu um erro durante a execução do SFC. Código de saída: $($process.ExitCode)" -ForegroundColor Red
        Write-Log "Consulte o log em C:\Windows\Logs\CBS\CBS.log para mais detalhes." -ForegroundColor Yellow
    }
    Read-Host "`nPressione ENTER para voltar ao menu"
}

function Executar-DISM {
    Clear-Host
    Write-Log "🛠️  Executando reparo da imagem do sistema (DISM)..." -ForegroundColor Yellow
    Write-Log "Este processo pode demorar bastante e requer conexão com a internet. Por favor, aguarde."

    $arguments = "/Online /Cleanup-Image /RestoreHealth"
    $process = Start-Process DISM.exe -ArgumentList $arguments -Wait -PassThru

    if ($process.ExitCode -eq 0) {
        Write-Log "`n✔️ Reparo da imagem DISM concluído com sucesso." -ForegroundColor Green
    } else {
        Write-Log "`n❌ Ocorreu um erro durante a execução do DISM. Código de saída: $($process.ExitCode)" -ForegroundColor Red
        Write-Log "Consulte o log em C:\Windows\Logs\DISM\dism.log para mais detalhes." -ForegroundColor Yellow
    }
    Read-Host "`nPressione ENTER para voltar ao menu"
}

function Executar-CHKDSK {
    Clear-Host
    Write-Log "💾 Agendando verificação de disco (CHKDSK)..." -ForegroundColor Yellow
    Write-Log "O CHKDSK será executado na próxima vez que o computador for reiniciado." -ForegroundColor Cyan

    try {
        # Usando a variável de ambiente para o disco do sistema.
        chkdsk.exe $env:SystemDrive /f /r
        Write-Log "`n✔️ CHKDSK agendado com sucesso para a unidade $env:SystemDrive." -ForegroundColor Green
        Write-Log "Reinicie o computador para iniciar a verificação." -ForegroundColor Yellow
    } catch {
        Write-Log "`n❌ Falha ao agendar o CHKDSK. Erro: $_" -ForegroundColor Red
    }
    Read-Host "`nPressione ENTER para voltar ao menu"
}

function Executar-Limpeza {
    Clear-Host
    Write-Log "🧹 Limpando arquivos temporários..." -ForegroundColor Yellow
    
    # Lista de pastas a serem limpas.
    $pastas = @(
        [System.IO.Path]::GetTempPath(), # Pasta Temp do usuário atual
        "$env:windir\Temp"               # Pasta Temp do Windows
    )

    foreach ($pasta in $pastas) {
        if (Test-Path $pasta) {
            Write-Log "`n🗂️  Limpando: $pasta" -ForegroundColor Cyan
            try {
                # Pega os itens e os remove. O -ErrorAction SilentlyContinue ignora arquivos em uso.
                Get-ChildItem -Path $pasta -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                Write-Log "✔️  Limpeza de $pasta concluída." -ForegroundColor Green
            } catch {
                # Captura erros inesperados durante a limpeza.
                Write-Log "❌ Falha ao limpar '$pasta': $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Log "`n⚠️ Pasta não encontrada: $pasta" -ForegroundColor Yellow
        }
    }
    Read-Host "`nPressione ENTER para voltar ao menu"
}

function Verificar-SMART {
    Clear-Host
    Write-Log "🧪 Verificando status SMART dos discos..." -ForegroundColor Yellow
    try {
        # Usando Get-CimInstance, que é o comando moderno.
        $discos = Get-CimInstance -ClassName Win32_DiskDrive
        foreach ($disco in $discos) {
            Write-Host "`nModelo: $($disco.Model)"
            $status = switch ($disco.Status) {
                "OK" { Write-Host "Status: $($disco.Status)" -ForegroundColor Green }
                default { Write-Host "Status: $($disco.Status)" -ForegroundColor Red }
            }
        }
    } catch {
        Write-Log "`n❌ Não foi possível verificar o status SMART. Erro: $($_.Exception.Message)" -ForegroundColor Red
    }
    Read-Host "`nPressione ENTER para voltar ao menu"
}


function Diagnostico-Rede-Debug {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Comando,

        [Parameter(Mandatory=$true)]
        [string]$MensagemSucesso,

        [Parameter(Mandatory=$true)]
        [string]$MensagemProgresso,
        
        [Parameter(Mandatory=$false)]
        [boolean]$PausarAoFinal = $true
    )

    try {
        Write-Host "`n$MensagemProgresso" -ForegroundColor Yellow
        
        # O comando Invoke-Expression executa uma string como se fosse um comando
        Invoke-Expression -Command $Comando

        Write-Host "`n✔️ $MensagemSucesso" -ForegroundColor Green
    }
    catch {
        Write-Host "`n❌ Ocorreu um erro ao executar o comando '$Comando'." -ForegroundColor Red
        Write-Host "   Detalhes do erro: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        # Uma pausa mais explícita para o usuário
        if($PausarAoFinal) {
            Read-Host "`nPressione Enter para continuar..." | Out-Null
        }
        
    }
}

function Diagnostico-Rede {
    
    # O loop do-until garante que o menu seja exibido pelo menos uma vez
    # e continue aparecendo até que a escolha seja "0".
    do {
        Clear-Host
        Write-Host "📅 MENU DE CONFIGURAÇÃO DE REDE" -ForegroundColor Cyan
        Write-Host "`n[1] 🌐 Renovar Configurações de Rede (Liberar, Renovar, Limpar DNS)" -ForegroundColor Yellow
        Write-Host "[2] 🔁 Reset de IP (Liberar e Renovar IP)" -ForegroundColor Yellow
        Write-Host "[3] 🧹 Limpar DNS (Limpar cache DNS)" -ForegroundColor Yellow
        Write-Host "[4] 📴 Desconectar IP (Liberar IP atual)" -ForegroundColor Yellow
        Write-Host "[5] 📶 Reconectar IP (Solicitar novo IP)" -ForegroundColor Yellow
        Write-Host "[0] ⬅️ Voltar ao menu principal" -ForegroundColor Gray

        $escolhaREDE = Read-Host "`nEscolha uma opção"

        switch ($escolhaREDE) {
            "1" {
                # Executa cada comando sem pausar
                Diagnostico-Rede-Debug  -Comando "ipconfig /release" -MensagemProgresso "Liberando IP atual..." -MensagemSucesso "IP Liberado." -PausarAoFinal $false
                Diagnostico-Rede-Debug  -Comando "ipconfig /renew" -MensagemProgresso "Renovando concessão de IP..." -MensagemSucesso "IP Renovado." -PausarAoFinal $false
                Diagnostico-Rede-Debug  -Comando "ipconfig /flushdns" -MensagemProgresso "Limpando cache DNS..." -MensagemSucesso "Cache DNS limpo." -PausarAoFinal $false
            
                # Adiciona uma mensagem final e uma única pausa
                Write-Host "`n✅ Feito!" -ForegroundColor Green
                Read-Host "`nPressione Enter para continuar..." | Out-Null
            }
            "2" {
                Diagnostico-Rede-Debug -Comando "ipconfig /release" -MensagemProgresso "Liberando IP atual..." -MensagemSucesso "IP Liberado." -PausarAoFinal $false
                Diagnostico-Rede-Debug -Comando "ipconfig /renew" -MensagemProgresso "Solicitando novo IP..." -MensagemSucesso "Reset de IP feito." -PausarAoFinal $false
                
                # Adiciona uma mensagem final e uma única pausa
                Write-Host "`n✅ Feito!" -ForegroundColor Green
                Read-Host "`nPressione Enter para continuar..." | Out-Null
            }
            "3" {
                Diagnostico-Rede-Debug -Comando "ipconfig /flushdns" -MensagemProgresso "Limpando cache DNS..." -MensagemSucesso "Cache DNS limpo." -PausarAoFinal $false

                # Adiciona uma mensagem final e uma única pausa
                Read-Host "`nPressione Enter para continuar..." | Out-Null
            }
            "4" {
                Diagnostico-Rede-Debug -Comando "ipconfig /release" -MensagemProgresso "Desconectar IP..." -MensagemSucesso "IP atual liberado." -PausarAoFinal $false
                
                # Adiciona uma mensagem final e uma única pausa
                Read-Host "`nPressione Enter para continuar..." | Out-Null
            }
            "5" {
                Diagnostico-Rede-Debug -Comando "ipconfig /renew" -MensagemProgresso "Reconectar IP..." -MensagemSucesso "IP renovado." -PausarAoFinal $false
            
                # Adiciona uma mensagem final e uma única pausa
                Read-Host "`nPressione Enter para continuar..." | Out-Null
            }
            "0" {
                Write-Host "`nSaindo do menu de rede..." -ForegroundColor Gray
            }
            Default {
                Write-Host "`n❌ Opção inválida. Tente novamente." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    } while ($escolhaREDE -ne "0")
}


# function Diagnostico-Rede {
#     Clear-Host
#     Write-Log "🌐 Executando diagnóstico de rede..." -ForegroundColor Yellow
#     try {
#         Write-Log "Liberando concessão de IP..."
#         ipconfig /release | Out-Null
#         Write-Log "Renovando concessão de IP..."
#         ipconfig /renew | Out-Null
#         Write-Log "Limpando cache DNS..."
#         ipconfig /flushdns | Out-Null
#         Write-Log "`n✔️ Diagnóstico de rede concluído com sucesso." -ForegroundColor Green
#     } catch {
#         Write-Log "`n❌ Ocorreu um erro durante o diagnóstico de rede: $($_.Exception.Message)" -ForegroundColor Red
#     }
#     Read-Host "`nPressione ENTER para voltar ao menu"
# }

function Reiniciar-WU {
    Clear-Host
    Write-Log "♻️  Redefinindo componentes do Windows Update..." -ForegroundColor Yellow
    
    $servicos = "wuauserv", "cryptSvc", "bits", "msiserver"
    $pastas = @(
        "$env:windir\SoftwareDistribution",
        "$env:windir\System32\catroot2"
    )

    try {
        Write-Log "Parando serviços do Windows Update..."
        Stop-Service -Name $servicos -Force -ErrorAction Stop

        Write-Log "Renomeando pastas de cache..."
        foreach ($pasta in $pastas) {
            if (Test-Path $pasta) {
                Rename-Item -Path $pasta -NewName "$($pasta).old" -Force -ErrorAction Stop
            }
        }

        Write-Log "Iniciando serviços do Windows Update..."
        Start-Service -Name $servicos -ErrorAction Stop

        Write-Log "`n✔️ Componentes do Windows Update redefinidos com sucesso." -ForegroundColor Green
    } catch {
        Write-Log "`n❌ Falha ao redefinir o Windows Update. Erro: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "Pode ser necessário reiniciar o computador." -ForegroundColor Yellow
    }
    
    Read-Host "`nPressione ENTER para voltar ao menu"
}

function Agendar-Tarefa {
    Clear-Host
    Write-Host "📅 MENU DE AGENDAMENTO DE TAREFAS" -ForegroundColor Cyan
    Write-Host "`n[1] Agendar limpeza diária do TEMP às 04:00"
    Write-Host "[0] Voltar ao menu principal"
    $escolha = Read-Host "`nEscolha uma opção"

    switch ($escolha) {
        "1" {
            $pastaAgendada = "C:\Agendati"
            if (-not (Test-Path $pastaAgendada)) {
                New-Item -Path $pastaAgendada -ItemType Directory | Out-Null
            }

            $scriptLimpeza = @"
            `$pastas = @(
                `"`$env:TEMP`",
                `"`$env:windir\Temp`"
            )
            foreach (`$pasta in `$pastas) {
                try {
                    Get-ChildItem -Path `$pasta -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                } catch {}
            }
"@

            $scriptPath = "$pastaAgendada\limpeza.ps1"
            Set-Content -Path $scriptPath -Value $scriptLimpeza -Encoding UTF8

            $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`""
            $trigger = New-ScheduledTaskTrigger -Daily -At 4:00AM
            $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
            $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal

            Register-ScheduledTask -TaskName "Limpeza_TEMP_Diaria" -InputObject $task -Force

            Write-Host "`n✔️  Tarefa agendada com sucesso! Será executada todos os dias às 04:00." -ForegroundColor Green
            Pause
}
        "0" { return }
        Default {
            Write-Host "`n❌ Opção inválida. Tente novamente." -ForegroundColor Red
            Start-Sleep -Seconds 2
            Agendar-Tarefa
        }
    }
}

function Limpar-FilaImpressao {
    [CmdletBinding()]
    param(
        [string] $PrinterName  # opcional, se quiser focar em só uma impressora
    )
    try {
        Write-Host "🖨️  Parando serviço de impressão..." -ForegroundColor Yellow
        Stop-Service Spooler -Force

        Write-Host "🔪 Matando processos remanescentes..." -ForegroundColor Yellow
        Get-Process spoolsv -ErrorAction SilentlyContinue | Stop-Process -Force

        Write-Host "🗑️  Limpando arquivos de spool..." -ForegroundColor Yellow
        Remove-Item -Path "$env:WINDIR\System32\spool\PRINTERS\*" -Force -Recurse -ErrorAction SilentlyContinue

        if ($PrinterName) {
            Write-Host "❌ Removendo driver da impressora $PrinterName..." -ForegroundColor Yellow
            # Remove-Printer só existe no Windows 8+/Server 2012+
            Remove-Printer -Name $PrinterName -ErrorAction SilentlyContinue
            # (re)instalar driver pode ser feito aqui se você tiver o INF disponível:
            # Add-Printer -Name $PrinterName -DriverName "NomeDoDriver" -PortName "PORTA"
        }

        Write-Host "▶️  Reiniciando serviço de impressão..." -ForegroundColor Yellow
        Start-Service Spooler

        Write-Host "✅ Spooler resetado." -ForegroundColor Green
    } catch {
        Write-Error "❌ Falha ao resetar spooler: $_"
    }
    Pause
}

#endregion

#region Lógica Principal de Execução

# Se o script foi chamado com o parâmetro -ScheduledClean, ele apenas executa a limpeza e sai.
if ($ScheduledClean.IsPresent) {
    # Suprime toda a saída visual para execução silenciosa
    Executar-Limpeza | Out-Null
    exit
}

# Loop principal do menu interativo
do {
    Mostrar-Menu
    $opcao = Read-Host "Escolha uma opção"

    switch ($opcao) {
        "0" { exit }
        "1" { Executar-SFC }
        "2" { Executar-DISM }
        "3" { Executar-CHKDSK }
        "4" { Executar-Limpeza }
        "5" { Verificar-SMART }
        "6" { Diagnostico-Rede }
        "7" { Reiniciar-WU }
        "8" { Agendar-Tarefa }
        "9" { Limpar-FilaImpressao }
        default {
            Write-Log "`n❗ Opção inválida. Por favor, tente novamente." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while ($true)

#endregion
# SIG # Begin signature block
# MIIFZwYJKoZIhvcNAQcCoIIFWDCCBVQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU+1oSD1ITPKrY6lkWQFfwQjfs
# hlKgggMEMIIDADCCAeigAwIBAgIQNpJ3aGZvmopKsMhVmpuZUDANBgkqhkiG9w0B
# AQsFADAYMRYwFAYDVQQDDA1EdWNrRGV2IFRvb2xzMB4XDTI1MDYyNzAyNTY0M1oX
# DTI2MDYyNzAzMTY0M1owGDEWMBQGA1UEAwwNRHVja0RldiBUb29sczCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBAKn4Kp9OE2fKY7IgOxgVryfIA2r9+xSj
# RrqgXPquezWZEFz/XWm1ULBTxf3Ij6JOYKcNb7xdjEceAWEOLnisQTd4DLsNum3N
# CBfWEiJwkwdSdwQ/imwNluRl6ouM5odNc9gimUpOj96bHoqKCzbw/AuEi5EKF/KU
# rHbYvKnSj+4aWRzgtFaqYXMhDNuxrGdTFVJUgbwRkSDH7Yk8PCQVzPLD9G8DekZf
# X/VMamAH5eU39Awg8RljBXYYyi/dlOrjkvO9wTt/eciqsMqdzC2rTjBJwovNnBTM
# i82cugjUQq0JeMewACStnH8uPbHhloVAaDDCM6o4gWcxgP3+Fg+nOVkCAwEAAaNG
# MEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQW
# BBRqedNOpH/kDJiAX69bLw20ATSysTANBgkqhkiG9w0BAQsFAAOCAQEApP7dLlux
# WBqwC1ZZSTR2yCWsTptUieXUP7zNuCS0zjU9aChbZS/zMBpsJ1Y93KhOW9yso7o+
# gRyJdOZrJWOyWsLeSEPcBMIl1PqvShv4QhcJ/fd0la5VlmXpeW2xvpZ+JaLqljm6
# xSXrxoA7sS5b7ixBmAGinqPUuZXswxVSsjxvQHUcDiRs1kQdRATZULPQ55viYCpd
# v0+i/rFZDDkUvHLy3ZVNIKfUEzt7hOOrDPhBjFdoLbcG3RDQ+E/xHLOIxLsxXFQm
# XgX5AkK3rvQGRlM/CAtnyHJVvckuOCzkcWBfmYNvre63g4oDGCAhJnpxQy9F8Bse
# I2ZVOAlcgTVG0TGCAc0wggHJAgEBMCwwGDEWMBQGA1UEAwwNRHVja0RldiBUb29s
# cwIQNpJ3aGZvmopKsMhVmpuZUDAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEK
# MAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3
# AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUMclOgRAqranqOTCx
# KcnKMDpg6igwDQYJKoZIhvcNAQEBBQAEggEAjsx03xrVUnL4TW/CFdOCEkrucDqw
# JmU0DbmwIWhWwbPzx50BWvpee7x/VfQPHOC7QZwugH7vSQKs5LrjcsdMLDYwqGfw
# YfTCarXNbdNzdL3xd0E6wOsnW4VY93d6OzVK4mwOeZ3Cc6zDcTDbuDbekZglHL0X
# 0AKmxu9R5vkaeNRRT5OsQPtcfpnRPqITqu5i1Ie1LTPGYMYTjZUuGERTGXuYuGBL
# z6pUPGzcJRZesNjB+qVT4A9wy/QGgj8tm7DLBcHw92DVicFNhYapwqjKx7xeOf2d
# v9k9f7KVMYCnhNoDXx8Aa2zwhLC9W4kS+mVc9sy3fFBv9OWqMV4oxJ9IhA==
# SIG # End signature block
