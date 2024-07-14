#! /usr/bin/python3
#
# Generate pie charts
# Need to run jfr_to_csv.sh to generate all-output.csv first
# Usage: python3 plot_csv.py <all-output-csv> <project-name> <output-dir>
# Forexample: cat projects.txt | xargs -n 1 -I {} python3 plot_csv.py /path/to/jfr_to_csv_output/{}/all-output.csv {} charts
#
import os
import csv
import sys
import matplotlib.pyplot as plot


def get_color(category):
    return {
        "STDLIB": "red",
        "AJ": "orange",
        "MOP": "yellow",
        "RVM": "green",
        "PROJ": "blue",
        "LIB": "indigo",
        "NATIVE": "violet",
        "ASM": "silver",
        "OTHER": "pink",
        "UNKNOWN": "lightgreen"
    }.get(category)


def read_csv(csv_path):
    all_outputs = []
    with open(csv_path) as f:
        for line in csv.reader(f):
            all_outputs.append(line[:-1])
    
    # Order is now: without mop, with mop, without hot
    all_outputs[0], all_outputs[1] = all_outputs[1], all_outputs[0]
    return all_outputs


def create_plot(csv_path, project_name, output_dir):
    print('Loading {} and generating {}.png to {}'.format(csv_path, project_name, output_dir))

    fig, ax = plot.subplots(1, 3, figsize=(15, 5))
    categories = ["STDLIB", "AJ", "MOP", "RVM", "PROJ", "LIB", "NATIVE", "ASM", "OTHER", "UNKNOWN"]
    all_samples = read_csv(csv_path)

    for samples_idx in range(3):
        samples = all_samples[samples_idx]

        display_samples = []
        display_categories = []
        color_categories = []
        
        total_samples = sum([int(sample) for sample in samples])
        for i in range(len(samples)):
            if samples[i] != 0 and round(int(samples[i]) / total_samples, 3) > 0:
                display_samples.append(samples[i])
                display_categories.append('{} ({}s)'.format(categories[i], round(int(samples[i]) * 0.005, 5)))
                color_categories.append(get_color(categories[i]))
        ax[samples_idx].pie(display_samples, labels=display_categories, autopct='%1.1f%%', colors=color_categories, textprops={'fontsize': 8})

    plot.savefig(os.path.join(output_dir, project_name + '.png'), bbox_inches='tight')


def main(argv=None):
    argv = argv or sys.argv

    if len(argv) != 4:
        print('Usage: python3 plot_csv.py <all-output-csv> <project-name> <output-dir>')
        exit(1)

    create_plot(argv[1], argv[2], argv[3])
    

if __name__ == '__main__':
    main()
