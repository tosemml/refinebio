# Generated by Django 3.2.4 on 2021-06-11 19:00

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("data_refinery_common", "0065_auto_20210324_1948"),
    ]

    operations = [
        migrations.RenameField(
            model_name="downloaderjob", old_name="nomad_job_id", new_name="batch_job_id",
        ),
        migrations.RenameField(
            model_name="processorjob", old_name="nomad_job_id", new_name="batch_job_id",
        ),
        migrations.RenameField(
            model_name="surveyjob", old_name="nomad_job_id", new_name="batch_job_id",
        ),
        migrations.AddField(
            model_name="downloaderjob",
            name="batch_job_queue",
            field=models.CharField(max_length=100, null=True),
        ),
        migrations.AddField(
            model_name="processorjob",
            name="batch_job_queue",
            field=models.CharField(max_length=100, null=True),
        ),
        migrations.AddField(
            model_name="processorjob",
            name="downloader_job",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                to="data_refinery_common.downloaderjob",
            ),
        ),
        migrations.AddField(
            model_name="surveyjob",
            name="batch_job_queue",
            field=models.CharField(max_length=100, null=True),
        ),
        migrations.AddField(
            model_name="surveyjob",
            name="retried_job",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                to="data_refinery_common.surveyjob",
            ),
        ),
        migrations.AlterField(
            model_name="surveyjob", name="ram_amount", field=models.IntegerField(default=1024),
        ),
    ]
