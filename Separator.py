import os
import argparse
import torch
import torchaudio
from demucs import pretrained
from demucs.apply import apply_model
import subprocess

def convert_to_wav(input_path):
    output_path = os.path.splitext(input_path)[0] + ".wav"
    command = ["ffmpeg", "-i", input_path, output_path]
    subprocess.run(command, check=True)
    os.remove(input_path)
    return output_path

def slice_audio(wav, sr, slice_duration=10):
    num_samples = slice_duration * sr
    slices = [wav[:, i:i + num_samples] for i in range(0, wav.size(1), num_samples)]
    return slices

def separate_vocals_and_background(model_name='mdx_extra_q', device=None, slice_duration=10):
    # 确保输出文件夹存在
    os.makedirs('raw', exist_ok=True)
    os.makedirs('results', exist_ok=True)

    # 加载预训练的Demucs模型
    model = pretrained.get_model(model_name)

    # 设置设备
    if device is None:
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model.to(device)

    # 处理每一个音频文件
    input_folder = 'musics'
    for file_name in os.listdir(input_folder):
        input_path = os.path.join(input_folder, file_name)
        if file_name.endswith('.wav'):
            pass
        elif file_name.endswith('.mp3') or file_name.endswith('.flac'):
            input_path = convert_to_wav(input_path)
        else:
            continue

        file_base_name = os.path.splitext(os.path.basename(input_path))[0]
        background_output_path = os.path.join('results', f"{file_base_name}.wav")
        
        # 检查结果文件是否已经存在
        if os.path.exists(background_output_path):
            print(f"File {background_output_path} already exists, skipping.")
            continue

        # 读取音频文件
        wav, sr = torchaudio.load(input_path)
        wav = wav.to(device)

        # 将音频切片为较小的段
        slices = slice_audio(wav, sr, slice_duration)
        vocal_slices = []
        background_slices = []

        for slice_wav in slices:
            # 增加batch维度
            slice_wav = slice_wav.unsqueeze(0)

            # 运行模型进行分离
            with torch.no_grad():
                sources = apply_model(model, slice_wav, device=device, split=True).squeeze(0)

            # 获取人声部分，第四个通道是人声
            vocals = sources[3]

            # 获取背景部分，组合前三个通道
            background = sources[0] + sources[1] + sources[2]

            # 移除batch维度
            vocal_slices.append(vocals.squeeze(0))
            background_slices.append(background.squeeze(0))

        # 合并切片为完整的音频
        full_vocals = torch.cat(vocal_slices, dim=-1)
        full_background = torch.cat(background_slices, dim=-1)

        # 构建输出文件路径
        vocal_output_path = os.path.join('raw', f"{file_base_name}.wav")

        # 保存分离出来的人声和背景部分
        torchaudio.save(vocal_output_path, full_vocals.cpu(), sr)
        torchaudio.save(background_output_path, full_background.cpu(), sr)

    print("人声和背景分离完成")

def main():
    parser = argparse.ArgumentParser(description="Demucs Vocal and Background Separator")
    parser.add_argument('--model_name', type=str, default='mdx_extra_q', help='Pretrained model to use for separation')
    parser.add_argument('--device', type=str, default=None, help='Device to use for computation (default: auto-detect)')
    parser.add_argument('--slice_duration', type=int, default=180, help='Duration of each audio slice in seconds')

    args = parser.parse_args()

    separate_vocals_and_background(args.model_name, args.device, args.slice_duration)

if __name__ == "__main__":
    main()
