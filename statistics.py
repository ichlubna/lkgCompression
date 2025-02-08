import numpy as np
import dcor
from sklearn.feature_selection import mutual_info_regression

nums = "0.01153846154	-0.01153846154	0.05	0.3038461538	0.6923076923	0.8576923077"
nums2 = "0.001802270032	0.009638958333	0.02735195353	0.04948666026	0.08705970673	0.1069567091"
a = np.array(nums.split(), dtype=float)
b = np.array(nums2.split(), dtype=float)
print(a)
print(b)
#print(dcor.distance_correlation(a, b))
mi = mutual_info_regression(a.reshape(-1, 1), b)
print(mi[0])
