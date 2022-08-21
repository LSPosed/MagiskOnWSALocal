import copy
import json
import random
from threading import Thread
import time
from collections import deque
from math import inf
from pathlib import Path

import psutil
import requests
from reprint import output
from requests.adapters import HTTPAdapter
from requests.sessions import Session


class Port_Getter:
    @staticmethod
    def busyports():
        return set(i.laddr.port for i in psutil.net_connections())

    def __init__(self):
        self.assigned = set()

    def randomport(self):
        port = random.randint(1, 65535)
        while port in Port_Getter.busyports() or port in self.assigned:
            port = random.randint(1, 65535)
        self.assigned.add(port)
        return port


class Adapter(HTTPAdapter):
    def __init__(self, port, *args, **kwargs):
        self._source_port = port
        super(Adapter, self).__init__(*args, **kwargs)


class UserSession(Session):
    portassigner = Port_Getter()

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.headers.update(
            {'connection': 'close'})
        self.setport()

    def setport(self):
        port = UserSession.portassigner.randomport()
        self.mount('http://', Adapter(port))
        self.mount('https://', Adapter(port))


class Multidown:
    def __init__(self, dic, id):
        self.count = 0
        self.completed = False
        self.id = id
        self.dic = dic
        self.position = self.getval('position')

    def getval(self, key):
        return self.dic[self.id][key]

    def setval(self, key, val):
        self.dic[self.id][key] = val

    def worker(self):
        filepath = self.getval('filepath')
        path = Path(filepath)
        end = self.getval('end')
        if not path.exists():
            start = self.getval('start')
        else:
            self.count = path.stat().st_size
            start = self.getval('start') + self.count
        url = self.getval('url')
        self.position = start
        with open(path, 'ab+') as f:
            if self.count != self.getval('length'):
                s = UserSession()
                r = s.get(
                    url, headers={'range': 'bytes={0}-{1}'.format(start, end)}, stream=True)
                while True:
                    if (chunk := next(r.iter_content(128 * 1024), None)):
                        f.write(chunk)
                        self.count += len(chunk)
                        self.position += len(chunk)
                        self.setval('count', self.count)
                        self.setval('position', self.position)
                    else:
                        break

                r.close()
                s.close()
        if self.count == self.getval('length'):
            self.completed = 1
            self.setval('completed', 1)


class Singledown:
    def __init__(self):
        self.count = 0
        self.completed = False
        
    def worker(self, url, path):
        with requests.get(url, stream=True) as r:
            with path.open('wb') as file:
                for chunk in r.iter_content(1048576):
                    if chunk:
                        self.count += len(chunk)
                        file.write(chunk)
        self.completed = True

class Downloader:
    def __init__(self):
        self.recent = deque([0] * 12, maxlen=12)
        self.recentspeeds = deque([0] * 200, maxlen=200)
        self.dic = dict()
        self.workers = []

    # stops the download in case a thread fails

    def download(self, url, filepath, num_connections=20):
        self.completed = False
        self.doneMB = None
        self.remaining = None
        
        f_path = filepath + '.progress.json'
        bcontinue = Path(f_path).exists()
        self.singlethread = False
        threads = []
        path = Path(filepath)
        head = requests.head(url)
        try:
            # 1MB = 1,000,000 bytes
            size = int(int(head.headers["Content-Length"]) / 1000000)
            if size < 50:
                num_connections = 5
        except Exception:
            pass

        folder = '/'.join(filepath.split('/')[:-1])
        Path(folder).mkdir(parents=True, exist_ok=True)
        headers = head.headers
        total = headers.get('content-length')
        if not total:
            print(
                f'Cannot find the total length of the content of {url}, the file will be downloaded using a single thread.')
            sd = Singledown()
            th = Thread(target=sd.worker, args=(url, path))
            th.daemon = True
            self.workers.append(sd)
            th.start()
            total = inf
            self.singlethread = True
        else:
            total = int(total)
            if not headers.get('accept-ranges'):
                print(
                    'Server does not support the `range` parameter, the file will be downloaded using a single thread.')
                sd = self.Singledown()
                th = Thread(target=sd.singledown, args=(url, path))
                th.daemon = True
                self.workers.append(sd)
                th.start()
                self.singlethread = True
            else:
                if bcontinue:
                    try:
                        progress = json.loads(Path(f_path).read_text(),
                                          object_hook=lambda d: {int(k) if k.isdigit() else k: v for k, v in d.items()})
                    except: #if some error happened set bcontinue to False
                        bcontinue = False
                segment = total / num_connections
                self.dic['total'] = total
                self.dic['connections'] = num_connections
                for i in range(num_connections):
                    if bcontinue:
                        try:
                            start = progress[i]['start']
                            end = progress[i]['end']
                            position = progress[i]['position']
                            length = progress[i]['length']
                        except: #if some error happened set bcontinue to False
                            bcontinue = False
                    if not bcontinue:
                        start = int(segment * i)
                        end = int(segment * (i + 1)) - \
                            (i != num_connections - 1)
                        position = start
                        length = end - start + (i != num_connections - 1)
                    self.dic[i] = {
                        'start': start,
                        'position': position,
                        'end': end,
                        'filepath': filepath + '.' + str(i).zfill(2) + '.part',
                        'count': 0,
                        'length': length,
                        'url': url,
                        'completed': False
                    }

                for i in range(num_connections):
                    md = Multidown(self.dic, i)
                    th = Thread(target=md.worker)
                    th.daemon = True
                    threads.append(th)
                    th.start()
                    self.workers.append(md)

                Path(f_path).write_text(json.dumps(self.dic, indent=4))

        def dynamic_print():
            downloaded = 0
            totalMB = total / 1048576
            speeds = []
            interval = 0.04
            with output(initial_len=5, interval=500) as dynamic_print:
                while True:
                    Path(f_path).write_text(json.dumps(self.dic, indent=4))
                    status = sum([i.completed for i in self.workers])
                    downloaded = sum(i.count for i in self.workers)
                    self.recent.append(downloaded)
                    done = int(100 * downloaded / total)
                    self.doneMB = downloaded / 1048576
                    gt0 = len([i for i in self.recent if i])
                    if not gt0:
                        speed = 0
                    else:
                        recent = list(self.recent)[12 - gt0:]
                        if len(recent) == 1:
                            speed = recent[0] / 1048576 / interval
                        else:
                            diff = [b - a for a, b in zip(recent, recent[1:])]
                            speed = sum(diff) / len(diff) / 1048576 / interval
                    speeds.append(speed)
                    self.recentspeeds.append(speed)
                    self.remaining = totalMB - self.doneMB
                    if self.singlethread:
                        dynamic_print[0] = '[ Downloaded: {0:.2f} MB ]'.format(self.doneMB)
                    else:
                        dynamic_print[0] = '[{0}{1}] {2}'.format(
                            '\u2588' * done, '\u00b7' * (100 - done), str(done)) + '% completed'
                        dynamic_print[1] = '{0:.2f} MB downloaded, {1:.2f} MB total, {2:.2f} MB remaining, download speed: {3:.2f} MB/s'.format(
                            self.doneMB, totalMB, self.remaining, speed)
                    if status == len(self.workers):
                        if not self.singlethread:
                            BLOCKSIZE = 4096
                            BLOCKS = 1024
                            CHUNKSIZE = BLOCKSIZE * BLOCKS
                            with path.open('wb') as dest:
                                for i in range(num_connections):
                                    file = filepath + '.' + \
                                        str(i).zfill(2) + '.part'
                                    with Path(file).open('rb') as f:
                                        while (chunk := f.read(CHUNKSIZE)):
                                            dest.write(chunk)
                                    Path(file).unlink()
                        break
                    time.sleep(interval)
            status = sum([i.completed for i in self.workers])
            if status == len(self.workers):
                Path(f_path).unlink()
                self.completed = True
            else:
                # download stoped due to some reason!
                pass

            # prnting the progressbar
        th = Thread(target=dynamic_print)
        th.daemon = True
        th.start()
        # check if still downloading every 10 seconds
        while not self.completed:
            current_download = copy.deepcopy(self.doneMB)
            current_remaining = copy.deepcopy(self.remaining)
            time.sleep(10)  # check after 10 seconds if download progress
            if current_download == self.doneMB:
                raise Exception("An error has occurred!")
            if not self.singlethread: # another check for multi-thread download
                if current_remaining == self.remaining:
                    raise Exception("An error has occurred!")